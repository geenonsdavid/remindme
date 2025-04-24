import 'dart:convert'; // Pour encoder / décoder les données JSON
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';// Pour gérer les notifications locales
import 'package:shared_preferences/shared_preferences.dart';// Pour stocker les données localement
import 'package:timezone/data/latest.dart' as tz; // pour gérer les fuseaux horaires
import 'package:timezone/timezone.dart' as tz;

// Initialisation de la bibliothèque de notifications
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
    // Initialisation des notifications pour Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // initialisation du fuseau horaire
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris')); // Set your local timezone
    loadReminders(); // Charger les rappels enregistrés
    scheduleNotifications(); // 📌 Planifie les notifications pour chaque entretien

  }

  // Sauvegarde toute la liste des entretiens dans SharedPreferences
  Future<void> saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> stringDates = entretiens.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await prefs.setString('entretiens', jsonEncode(stringDates)); // Stocke en JSON
  }

  // Charge toute la liste des entretiens depuis SharedPreferences
  Future<void> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('entretiens');
    if (storedData == null) {
      return; // Pas de données stockées
    }
    // Si des données sont stockées, on les décode
    // et on les convertit en DateTime
    Map<String, dynamic> decodedData = jsonDecode(storedData);
    setState(() {
      entretiens = decodedData.map(
        (key, value) => MapEntry(key, DateTime.parse(value)),
      );
    });
    }
  // Génère un ID unique pour chaque notification
  int notificationsId(String name) => name.hashCode;

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
  
  // Supprime un entretien après confirmation
 void deleteEntretien(String name) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Confirmation"),
        content: Text("Voulez-vous vraiment supprimer l'entretien \"$name\" ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    setState(() {
      entretiens.remove(name);
    });
    saveReminders();
  }
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
        // on crée une nouvelle date avec 9h comme heure
    DateTime fixedTime = DateTime(date.year, date.month, date.day, 9, 0, 0);

    await flutterLocalNotificationsPlugin.zonedSchedule(
  notificationsId(name),// ID unique basé sur le nom de l'entretien
  'Rappel d\'entretien',
  'N\'oubliez pas l\'entretien de $name !',
  tz.TZDateTime.from(fixedTime, tz.local),
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
