import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:remindme/reminder_service.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ReminderService _reminderService;
  bool _isLoading = true;
  Set<int> _activeReminderIds = {};

  Map<String, DateTime> get entretiens => _reminderService.entretiens;

  @override
  void initState() {
    super.initState();
    _reminderService = ReminderService(flutterLocalNotificationsPlugin);
    _initializeReminders();
  }

  Future<void> _initializeReminders() async {
    try {
      await _reminderService.loadReminders();
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Impossible de charger les entretiens : $error");
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    _restoreNotifications();
  }

  Future<void> _restoreNotifications() async {
    try {
      await _reminderService.scheduleAll();
      await _refreshReminderStatus();
    } catch (error) {
      if (mounted) {
        _showError("Impossible de synchroniser les notifications : $error");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshReminderStatus() async {
    final notificationsEnabled =
        await _reminderService.areNotificationsEnabled();
    final scheduledIds = await _reminderService.scheduledNotificationIds();
    if (mounted) {
      setState(() {
        _activeReminderIds = notificationsEnabled ? scheduledIds : <int>{};
      });
    }
  }

  Future<void> addEntretien() async {
    var enteredName = '';
    DateTime? selectedDate;

    final entretien = await showDialog<({String name, DateTime date})>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Ajouter un entretien"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => enteredName = value,
                decoration: const InputDecoration(
                  labelText: "Nom de l'entretien",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                final name = enteredName.trim();
                if (name.isEmpty || selectedDate == null) {
                  _showError(
                    "Saisissez un nom et choisissez une date pour l’entretien.",
                  );
                  return;
                }
                final existingName =
                    entretiens.keys
                        .where(
                          (existingName) =>
                              existingName.trim().toLowerCase() ==
                              name.toLowerCase(),
                        )
                        .firstOrNull;
                var nameToSave = name;
                if (existingName != null) {
                  final existingDate = entretiens[existingName]!;
                  final replaceDate = await showDialog<bool>(
                    context: dialogContext,
                    builder:
                        (confirmationContext) => AlertDialog(
                          title: const Text("Entretien déjà enregistré"),
                          content: Text(
                            "« $existingName » est déjà prévu le "
                            "${existingDate.day}/${existingDate.month}/${existingDate.year}. "
                            "Voulez-vous remplacer cette date par "
                            "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year} ?",
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () =>
                                      Navigator.pop(confirmationContext, false),
                              child: const Text("Garder la date"),
                            ),
                            TextButton(
                              onPressed:
                                  () =>
                                      Navigator.pop(confirmationContext, true),
                              child: const Text("Remplacer"),
                            ),
                          ],
                        ),
                  );
                  if (replaceDate != true) {
                    return;
                  }
                  if (!dialogContext.mounted) {
                    return;
                  }
                  nameToSave = existingName;
                }

                Navigator.pop(dialogContext, (
                  name: nameToSave,
                  date: selectedDate!,
                ));
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );

    if (entretien == null || !mounted) {
      return;
    }

    try {
      entretiens[entretien.name] = entretien.date;
      await _reminderService.saveReminders();
      if (mounted) {
        setState(() {});
      }

      final permissionGranted = await _reminderService.requestPermissions();
      await _reminderService.scheduleNotification(
        entretien.name,
        entretien.date,
      );
      await _refreshReminderStatus();
      if (!permissionGranted && mounted) {
        _showError("Autorisez les notifications pour recevoir vos rappels.");
      }
    } catch (error) {
      if (mounted) {
        _showError("Impossible d’enregistrer l’entretien : $error");
      }
    }
  }

  Future<void> deleteEntretien(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Confirmation"),
          content: Text(
            "Voulez-vous vraiment supprimer l'entretien \"$name\" ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                "Supprimer",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _reminderService.deleteEntretien(name);
      if (mounted) {
        setState(() {
          _activeReminderIds.remove(_reminderService.notificationsId(name));
        });
      }
    }
  }

  Future<void> updateEntretienDate(String name) async {
    final currentDate = entretiens[name];
    if (currentDate == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Confirmation"),
          content: Text(
            "Souhaitez-vous ajouter un an à la date de l'entretien \"$name\" ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Confirmer"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _reminderService.updateEntretienDate(name);
      final newDate = entretiens[name];
      if (newDate != null && mounted) {
        await _refreshReminderStatus();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Nouvelle date pour \"$name\" : "
              "${newDate.day}/${newDate.month}/${newDate.year}",
            ),
          ),
        );
      }
    }
  }

  Future<void> toggleNotification(String name, DateTime date) async {
    if (kIsWeb) {
      _showError(
        "Les notifications ne sont pas disponibles dans la version Web. "
        "Utilisez l’application Android ou iOS pour activer les rappels.",
      );
      return;
    }

    final notificationId = _reminderService.notificationsId(name);
    try {
      if (_activeReminderIds.contains(notificationId)) {
        await _reminderService.cancelNotification(name);
        if (mounted) {
          setState(() => _activeReminderIds.remove(notificationId));
          _showError("Rappel désactivé pour « $name ».");
        }
        return;
      }

      final permissionGranted = await _reminderService.requestPermissions();
      if (!permissionGranted) {
        await _refreshReminderStatus();
        if (mounted) {
          _showError(
            "Autorisez les notifications dans les réglages pour activer ce rappel.",
          );
        }
        return;
      }

      final scheduled = await _reminderService.scheduleNotification(name, date);
      await _refreshReminderStatus();
      if (!mounted) return;

      if (!scheduled) {
        _showError(
          "La date de « $name » est passée : choisissez une date future.",
        );
      } else if (_activeReminderIds.contains(notificationId)) {
        _showError(
          "Rappel activé pour « $name » le "
          "${date.day}/${date.month}/${date.year} à 9 h.",
        );
      } else {
        _showError(
          "Le rappel a été planifié, mais les notifications sont désactivées dans les réglages.",
        );
      }
    } catch (error) {
      if (mounted) {
        _showError("Impossible de modifier le rappel : $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children:
                    entretiens.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.key),
                        subtitle: Text(
                          '${entry.value.day}/${entry.value.month}/${entry.value.year}',
                        ),
                        leading: const Icon(Icons.event),
                        onTap: () => updateEntretienDate(entry.key),
                        trailing: SizedBox(
                          width: 150,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.notifications,
                                  color:
                                      _activeReminderIds.contains(
                                            _reminderService.notificationsId(
                                              entry.key,
                                            ),
                                          )
                                          ? Colors.red
                                          : null,
                                ),
                                tooltip:
                                    _activeReminderIds.contains(
                                          _reminderService.notificationsId(
                                            entry.key,
                                          ),
                                        )
                                        ? "Désactiver le rappel"
                                        : "Activer le rappel",
                                onPressed:
                                    () => toggleNotification(
                                      entry.key,
                                      entry.value,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => deleteEntretien(entry.key),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
      floatingActionButton:
          _isLoading
              ? null
              : FloatingActionButton(
                onPressed: addEntretien,
                tooltip: "Ajouter un entretien",
                child: const Icon(Icons.add),
              ),
    );
  }
}
