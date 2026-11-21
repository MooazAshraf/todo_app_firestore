import 'package:flutter/material.dart';

import 'task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // One stream, created once. Filtering is done locally => no extra reads/indexes.
  final _stream = tasksRef.orderBy('createdAt', descending: true).snapshots();
  final _removed = <String>{}; // hides swiped tiles instantly (until Firestore echoes)
  int _filter = 0; // 0 all, 1 active, 2 completed

  void _delete(Task t) {
    setState(() => _removed.add(t.id));
    tasksRef.doc(t.id).delete();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('"${t.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _removed.remove(t.id));
            tasksRef.doc(t.id).set(t.toMap());
          },
        ),
      ));
  }

  void _openSheet([Task? t]) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _Sheet(t),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final all = [
              for (final d in snap.data!.docs)
                if (!_removed.contains(d.id)) Task.fromDoc(d)
            ];
            final done = all.where((t) => t.done).length;
            final shown = _filter == 0
                ? all
                : all.where((t) => t.done == (_filter == 2)).toList();

            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('My Tasks',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$done of ${all.length} completed',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: all.isEmpty ? 0 : done / all.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: const Color(0xFFE3ECE7),
                    color: green,
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  for (final (i, label) in ['All', 'Active', 'Completed'].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == i,
                        selectedColor: green,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                            color: _filter == i ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text('Nothing here yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _Tile(
                          shown[i],
                          onTap: () => _openSheet(shown[i]),
                          onDelete: () => _delete(shown[i]),
                        ),
                      ),
              ),
            ]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSheet,
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.t, {required this.onTap, required this.onDelete});

  final Task t;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Priority.high.color, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: onTap,
          leading: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(t.done ? Icons.check_circle : Icons.circle_outlined,
                color: t.done ? green : Colors.grey),
            onPressed: () => tasksRef.doc(t.id).update({'done': !t.done}),
          ),
          title: Text(
            t.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: t.done ? Colors.grey : null,
              decoration: t.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: t.note.isEmpty
              ? null
              : Text(t.note, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: CircleAvatar(radius: 4, backgroundColor: t.priority.color),
        ),
      ),
    );
  }
}

class _Sheet extends StatefulWidget {
  const _Sheet(this.task);
  final Task? task;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _note = TextEditingController(text: widget.task?.note);
  late Priority _priority = widget.task?.priority ?? Priority.medium;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final t = widget.task;
    final data = Task(t?.id ?? '', title, _note.text.trim(), t?.done ?? false, _priority);
    if (t == null) {
      tasksRef.add(data.toMap());
    } else {
      tasksRef.doc(t.id).update(
          {'title': data.title, 'note': data.note, 'priority': _priority.index});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.task == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isNew ? 'New Task' : 'Edit Task',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for (final p in Priority.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _priority == p,
                onSelected: (_) => setState(() => _priority = p),
              ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: green, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _save,
              child: Text(isNew ? 'Add Task' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
