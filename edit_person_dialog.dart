import 'package:flutter/material.dart';
import 'main.dart';

class EditPersonDialog extends StatefulWidget {
  final Person person;

  const EditPersonDialog({required this.person});

  @override
  _EditPersonDialogState createState() => _EditPersonDialogState();
}

class _EditPersonDialogState extends State<EditPersonDialog> {
  late TextEditingController nameController;
  late TextEditingController cityController;
  late TextEditingController phoneNumberController;

  @override
  void initState() {
    super.initState();

    // Inicjalizacja kontrolerów tekstowych
    nameController = TextEditingController(text: widget.person.name);
    cityController = TextEditingController(text: widget.person.city);
    phoneNumberController = TextEditingController(text: widget.person.phoneNumber);
  }

  @override
  void dispose() {
    // Zwolnij zasoby kontrolerów tekstowych
    nameController.dispose();
    cityController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Person'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: cityController,
            decoration: InputDecoration(labelText: 'City'),
          ),
          TextField(
            controller: phoneNumberController,
            decoration: InputDecoration(labelText: 'Phone Number'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Zamknij dialog bez zapisywania zmian
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Zapisz zmiany i zwróć zaktualizowaną osobę do poprzedniego ekranu
            final editedPerson = Person(
              name: nameController.text,
              city: cityController.text,
              phoneNumber: phoneNumberController.text,
              avatar: widget.person.avatar,
              imageBytes: widget.person.imageBytes,
            );
            Navigator.pop(context, editedPerson);
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
