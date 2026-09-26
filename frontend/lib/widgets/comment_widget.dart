import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/comment.dart';
import 'package:hifazat_app/providers/user_provider.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CommentWidget extends StatefulWidget {
  final Comment comment;
  final int incidentId;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.incidentId,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  @override
  void initState() {
    super.initState();
    // When the widget is first created, trigger the fetch for this commenter's reputation
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.getReputationForUser(widget.comment.user.id);
  }

  @override
  Widget build(BuildContext context) {
    // We only need the UserProvider to check for ownership of the comment
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    final bool isOwner = currentUser?.id == widget.comment.user.id;
    final String username = widget.comment.user.username;

    return Card(
      elevation: 0,
      color: Colors.black.withOpacity(0.04),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      // FIX: Consumer listens to UserProvider changes to display reputation
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          final reputation = userProvider.reputationCache[widget.comment.user.id];
                          return Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.green.shade700, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                reputation?.reputationScore.toString() ?? '...', // Show '...' while loading
                                style: TextStyle(color: Colors.green.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Text(DateFormat.yMd().add_jm().format(widget.comment.createdAt.toLocal()), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    if (isOwner)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red))),
                      ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Report')),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'delete') {
                      _showDeleteConfirmationDialog(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
              child: Text(widget.comment.content),
            ),
            // FIX: Removed the vote buttons row entirely
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Delete Comment"),
          content: const Text("Are you sure you want to permanently delete this comment?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                incidentProvider.deleteComment(widget.incidentId, widget.comment.id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}