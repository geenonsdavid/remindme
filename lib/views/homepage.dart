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
  static const _pageBackground = Color(0xFFF4F7FB);
  static const _primaryColor = Color(0xFF3157D5);
  static const _textColor = Color(0xFF17233C);
  static const _mutedColor = Color(0xFF73809A);

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
    final entries = entretiens.entries.toList();

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: entries.isEmpty ? 3 : entries.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildWelcomeCard(entries.length);
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 28, bottom: 14),
                      child: Row(
                        children: [
                          const Text(
                            "Mes entretiens",
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${entries.length}',
                              style: const TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (entries.isEmpty) {
                    return _buildEmptyState();
                  }

                  final entry = entries[index - 2];
                  final notificationId = _reminderService.notificationsId(
                    entry.key,
                  );
                  final isReminderActive = _activeReminderIds.contains(
                    notificationId,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFE8EDF5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_outlined,
                            color: _primaryColor,
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '${entry.value.day}/${entry.value.month}/${entry.value.year}',
                            style: const TextStyle(
                              color: _mutedColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onTap: () => updateEntretienDate(entry.key),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip:
                                  isReminderActive
                                      ? "Désactiver le rappel"
                                      : "Activer le rappel",
                              onPressed:
                                  () => toggleNotification(
                                    entry.key,
                                    entry.value,
                                  ),
                              icon: Icon(
                                isReminderActive
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none_outlined,
                                color:
                                    isReminderActive
                                        ? _primaryColor
                                        : _mutedColor,
                              ),
                            ),
                            IconButton(
                              tooltip: "Supprimer",
                              onPressed: () => deleteEntretien(entry.key),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFF9AA5B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton:
          _isLoading
              ? null
              : FloatingActionButton(
                onPressed: addEntretien,
                tooltip: "Ajouter un entretien",
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
    );
  }

  Widget _buildWelcomeCard(int reminderCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF3157D5), Color(0xFF5578E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Gardez l’esprit tranquille",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reminderCount == 0
                      ? "Ajoutez un entretien pour commencer."
                      : "$reminderCount entretien${reminderCount > 1 ? 's' : ''} enregistré${reminderCount > 1 ? 's' : ''}.",
                  style: const TextStyle(
                    color: Color(0xFFE3E9FF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              color: _primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Aucun entretien pour le moment",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Appuyez sur + pour ajouter votre premier rappel.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor, height: 1.4),
          ),
        ],
      ),
    );
  }
}
