import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/contact.dart';
import '../../../../models/meeting.dart';
import '../../../onboarding_contacts/presentation/screens/contact_picker_screen.dart';
import '../../application/meetings_notifier.dart';

class ScheduleMeetingScreen extends ConsumerStatefulWidget {
  const ScheduleMeetingScreen({super.key});

  @override
  ConsumerState<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends ConsumerState<ScheduleMeetingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  int _durationMinutes = 30;
  MeetingCallType _callType = MeetingCallType.video;
  final List<SavedContact> _invitees = [];
  bool _creating = false;

  static const _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickInvitees() async {
    final result = await Navigator.of(context).push<List<SavedContact>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          title: 'Invite participants',
          multiSelect: true,
          excludeUserIds: _invitees.map((c) => c.contactUser!.id).toSet(),
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _invitees.addAll(result));
  }

  DateTime get _scheduledAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _schedule() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _invitees.isEmpty) return;
    setState(() => _creating = true);
    try {
      await ref.read(meetingsRepositoryProvider).createMeeting(
            title: title,
            description: _descriptionController.text.trim(),
            scheduledAt: _scheduledAt,
            durationMinutes: _durationMinutes,
            callType: _callType,
            inviteeIds: _invitees.map((c) => c.contactUser!.id).toList(),
          );
      ref.read(meetingsNotifierProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not schedule meeting: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSchedule = !_creating && _titleController.text.trim().isNotEmpty && _invitees.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule meeting')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.event_outlined)),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('${_date.day}/${_date.month}/${_date.year}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _durationMinutes,
            decoration: const InputDecoration(labelText: 'Duration'),
            items: [
              for (final m in _durationOptions) DropdownMenuItem(value: m, child: Text('$m minutes')),
            ],
            onChanged: (v) => setState(() => _durationMinutes = v ?? _durationMinutes),
          ),
          const SizedBox(height: 16),
          SegmentedButton<MeetingCallType>(
            segments: const [
              ButtonSegment(value: MeetingCallType.video, icon: Icon(Icons.videocam_outlined), label: Text('Video')),
              ButtonSegment(value: MeetingCallType.audio, icon: Icon(Icons.call_outlined), label: Text('Audio')),
            ],
            selected: {_callType},
            onSelectionChanged: (s) => setState(() => _callType = s.first),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_invitees.length} invited', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: _pickInvitees,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          for (final contact in _invitees)
            ListTile(
              title: Text(contact.customName.isNotEmpty ? contact.customName : contact.contactUser!.displayName),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _invitees.remove(contact)),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: canSchedule ? _schedule : null,
            child: _creating
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Schedule meeting'),
          ),
        ],
      ),
    );
  }
}
