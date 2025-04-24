import 'dart:convert'; // Importation pour JSON
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, DateTime> entretiens = {};

  @override
  void initState() {
    super.initState();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris')); // Set your local timezone
    loadReminders();
    scheduleNotifications(); // 📌 Planifie les notifications pour chaque entretien

  }

  // Sauvegarde toute la liste des entretiens
  Future<void> saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> stringDates = entretiens.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await prefs.setString('entretiens', jsonEncode(stringDates)); // Stocke en JSON
  }

  // Charge toute la liste des entretiens au démarrage
  Future<void> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('entretiens');
    if (storedData == null) {
      return; // Pas de données stockées
    }
    // Si des données sont stockées, on les décode
    // et on les convertit en DateTime
    Map<String, dynamic> decodedData = jsonDecode(storedData!);
    setState(() {
      entretiens = decodedData.map(
        (key, value) => MapEntry(key, DateTime.parse(value)),
      );
    });
    }

  // Ajoute un entretien et le sauvegarde
 void addEntretien() async {
  final TextEditingController nameController = TextEditingController();
  DateTime? selectedDate;

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Ajouter un entretien"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nom de l'entretien"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (pickedDate != null) {
                  selectedDate = pickedDate;
                }
              },
              child: const Text("Choisir une date"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Annuler"),
          ),
          TextButton(
  onPressed: () {
    if (nameController.text.isNotEmpty && selectedDate != null) {
      if (entretiens.containsKey(nameController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Un entretien avec ce nom existe déjà !")),
        );
        return;
      }
      setState(() {
        entretiens[nameController.text] = selectedDate!;
      });
      saveReminders();
      Navigator.pop(context);
    }
  },
  child: const Text("Ajouter"),
),
        ],
      );
    },
  );
}
  
  // Supprime un entretien et le sauvegarde
  void deleteEntretien(String name) {
    setState(() {
      entretiens.remove(name);
    });
    saveReminders(); // 💾 Sauvegarde immédiate après suppression
  }
  
  // Affiche une notification pour un entretien
  Future<void> showNotification(String name, DateTime date) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your_channel_id', 'your_channel_name',
            channelDescription: 'your_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
  0,
  'Rappel d\'entretien',
  'N\'oubliez pas l\'entretien de $name !',
  tz.TZDateTime.from(date, tz.local),
  platformChannelSpecifics,
  androidScheduleMode: AndroidScheduleMode.exact,
);

  }
  
  // Affiche une notification pour tous les entretiens
  void scheduleNotifications() {
    for (var entry in entretiens.entries) {
      showNotification(entry.key, entry.value);
    }
  }
  
  // Affiche une notification pour un entretien
  void scheduleNotification(String name, DateTime date) {
    showNotification(name, date);
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        children: entretiens.entries.map((entry) {
          return ListTile(
            title: Text(entry.key),
            subtitle: Text('${entry.value.day}/${entry.value.month}/${entry.value.year}'),
            leading: const Icon(Icons.event),
            trailing: SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
          
                  IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => scheduleNotification(entry.key, entry.value),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteEntretien(entry.key),
                ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addEntretien,
        tooltip: "Ajouter un entretien",
        child: const Icon(Icons.add),
      ),
    );
  }
}
