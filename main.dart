import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'edit_person_dialog.dart';

class Person {
  String name;
  String city;
  String phoneNumber;
  String avatar;
  Uint8List? imageBytes;

  Person({
    required this.name,
    required this.city,
    required this.phoneNumber,
    required this.avatar,
    required this.imageBytes,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name =
            "${json["name"]["title"]} ${json["name"]["first"]} ${json["name"]["last"]}",
        phoneNumber = json["phone"],
        city = json["location"]["city"],
        avatar = json["picture"]["large"];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'phoneNumber': phoneNumber,
      'avatar': avatar,
      'imageBytes': imageBytes,
    };
  }
}

class PersonNetworkService {
  static const String randomPersonURL = "https://randomuser.me/api/";

  Future<List<Person>> fetchPersons(int amount) async {
    final response =
        await http.get(Uri.parse('$randomPersonURL?results=$amount'));

    if (response.statusCode == 200) {
      final Map peopleData = json.decode(response.body);
      final List<dynamic> peoples = peopleData["results"];
      return peoples.map((json) => Person.fromJson(json)).toList();
    } else {
      throw Exception("Something gone wrong, ${response.statusCode}");
    }
  }

  Future<void> savePersons(List<Person> persons, {String? path}) async {
    // Zapisz dane do bazy danych
    final databasePath = await getDatabasesPath();
    final database = await openDatabase(
      join(databasePath, 'persons_database.db'),
      onCreate: (db, version) {
        return db.execute(
            'CREATE TABLE IF NOT EXISTS persons(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, city TEXT, phoneNumber TEXT, avatar TEXT, imageBytes BLOB)');
      },
      version: 1,
    );
    for (final person in persons) {
      await database.insert(
        'persons',
        person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}

Future<List<Person>> fetchPersonsFromDatabase() async {
  final databasePath = await getDatabasesPath();
  final database = await openDatabase(
    join(databasePath, 'persons_database.db'),
    version: 1,
  );
  final List<Map<String, dynamic>> queryResult =
      await database.query('persons');
  return queryResult.map((row) {
    return Person(
      name: row['name'],
      city: row['city'],
      phoneNumber: row['phoneNumber'],
      avatar: row['avatar'],
      imageBytes: row['imageBytes'],
    );
  }).toList();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PersonNetworkService personService = PersonNetworkService();
  int fetchAmount = 10;
  List<Person> peopleToShow = [];
  bool isOfflineMode = false;

  // Funkcja usuwająca wybraną osobę
  void deletePerson(Person person) async {
    final databasePath = await getDatabasesPath();
    final database = await openDatabase(
      join(databasePath, 'persons_database.db'),
      version: 1,
    );
    await database.delete(
      'persons',
      where: 'name = ?',
      whereArgs: [person.name],
    );
    setState(() {
      peopleToShow.remove(person);
    });
  }

  // Funkcja edytująca daną osobę

  Future<void> _refreshPeople() async {
    if (isOfflineMode) {
      final List<Person> people = await fetchPersonsFromDatabase();
      setState(() {
        peopleToShow = people;
      });
    } else {
      final List<Person> people = await personService.fetchPersons(fetchAmount);
      setState(() {
        peopleToShow = people;
      });
    }
  }

  void editPerson(Person person, BuildContext context) async {
    final editedPerson = await showDialog<Person>(
      context: context,
      builder: (BuildContext context) {
        return EditPersonDialog(person: person);
      },
    );

    if (editedPerson != null) {
      final databasePath = await getDatabasesPath();
      final database = await openDatabase(
        join(databasePath, 'persons_database.db'),
        version: 1,
      );
      await database.update(
        'persons',
        editedPerson.toMap(),
        where: 'name = ?',
        whereArgs: [person.name],
      );

      setState(() {
        final index = peopleToShow.indexOf(person);
        if (index != -1) {
          peopleToShow[index] = editedPerson;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isOfflineMode) const Text('Number of people to fetch: '),
                if (!isOfflineMode)
                  SizedBox(
                    width: 40,
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          fetchAmount = int.tryParse(value) ?? 0;
                        });
                      },
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: isOfflineMode
                      ? () async {
                          // Tryb offline - wyświetlanie danych z bazy danych
                          final List<Person> people =
                              await fetchPersonsFromDatabase();
                          setState(() {
                            peopleToShow = people;
                          });
                        }
                      : () async {
                          // Tryb online - pobieranie nowych danych
                          final List<Person> people =
                              await personService.fetchPersons(fetchAmount);
                          setState(() {
                            peopleToShow = people;
                          });
                        },
                  child: const Text('Fetch'),
                ),
                if (!isOfflineMode &&
                    peopleToShow
                        .isNotEmpty) // Wyświetlaj przycisk tylko w trybie online, gdy są dane do zapisu
                  ElevatedButton(
                    onPressed: () async {
                      // Zapisywanie danych
                      await personService.savePersons(peopleToShow);
                    },
                    child: const Text('Save'),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Offline Mode:'),
                Switch(
                  value: isOfflineMode,
                  onChanged: (value) {
                    setState(() {
                      isOfflineMode = value;
                      peopleToShow = [];
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: peopleToShow.isEmpty
                  ? const Center(
                      child: Text('Press Fetch button to load data.'))
                  : RefreshIndicator(
                      onRefresh: _refreshPeople,
                      child: ListView.builder(
                        itemCount: peopleToShow.length,
                        itemBuilder: (BuildContext context, int index) {
                          var currentPerson = peopleToShow[index];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(currentPerson.name),
                              leading: CircleAvatar(
                                backgroundImage:
                                    NetworkImage(currentPerson.avatar),
                                radius: 50,
                              ),
                              subtitle: Text(
                                "Phone: ${currentPerson.phoneNumber}"
                                "\nCity: ${currentPerson.city}",
                              ),
                              trailing: isOfflineMode
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            editPerson(currentPerson, context);
                                          },
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            // Usunięcie wybranej osoby
                                            deletePerson(currentPerson);
                                          },
                                          icon: const Icon(Icons.delete),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}
