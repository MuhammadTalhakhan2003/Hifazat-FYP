import 'package:flutter/material.dart';
// import 'package:hifazat_app/api/models/comment.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/providers/user_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/widgets/comment_widget.dart';
import 'package:hifazat_app/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CategoryStyle {
  final Color color;
  CategoryStyle({required this.color});
}

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({super.key});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  int? _incidentId;
  final TextEditingController _commentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newIncidentId = ModalRoute.of(context)!.settings.arguments as int?;
    if (newIncidentId != null && _incidentId != newIncidentId) {
      _incidentId = newIncidentId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchInitialData();
        }
      });
    }
  }

  void _fetchInitialData() async {
    if (_incidentId == null) return;
    
    final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    await incidentProvider.fetchIncidentDetails(_incidentId!);
    await incidentProvider.fetchComments(_incidentId!);

    final reporterId = incidentProvider.selectedIncident?.properties.reportedBy;
    if (reporterId != null) {
      await userProvider.getReputationForUser(reporterId);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleVote(Future<bool> voteFuture) async {
    final success = await voteFuture;
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You must be logged in to vote.'),
          action: SnackBarAction(
            label: 'LOGIN',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ),
      );
    }
  }
  
  void _onAddComment() {
    if (_commentController.text.trim().isEmpty || _incidentId == null) return;
    
    final provider = Provider.of<IncidentProvider>(context, listen: false);
    provider.addCommentToIncident(_incidentId!, _commentController.text.trim())
      .then((success) {
        if (success) {
          _commentController.clear();
          FocusScope.of(context).unfocus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add comment. Please try again.'), backgroundColor: Colors.red),
          );
        }
      });
  }

  CategoryStyle _getCategoryStyle(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'terrorism & extremism':
        return CategoryStyle(color: Colors.black);
      case 'violent crime & homicide':
        return CategoryStyle(color: Colors.red.shade800);
      case 'kidnapping & abduction':
        return CategoryStyle(color: Colors.blueGrey.shade800);
      case 'organized crime & trafficking':
        return CategoryStyle(color: Colors.brown.shade800);
      case 'theft & robbery':
        return CategoryStyle(color: Colors.deepOrange.shade800);
      case 'scams & fraud':
        return CategoryStyle(color: Colors.purple.shade800);
      case 'sexual violence & abuse':
        return CategoryStyle(color: Colors.pink.shade800);
      case 'public order & governance offenses':
        return CategoryStyle(color: Colors.indigo.shade800);
      case 'accidents & disasters':
        return CategoryStyle(color: Colors.green.shade800);
      case 'drug crimes':
        return CategoryStyle(color: Colors.teal.shade800);
      default:
        return CategoryStyle(color: Colors.grey.shade600);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Details')),
      body: Consumer2<IncidentProvider, UserProvider>(
        builder: (context, incidentProvider, userProvider, child) {
          if (incidentProvider.isLoading || incidentProvider.selectedIncident == null) {
            return const LoadingIndicator();
          }
          final incident = incidentProvider.selectedIncident!;
          final props = incident.properties;
          final userVote = userProvider.user != null ? incidentProvider.userVoteStatus[incident.id] : null;
          final style = _getCategoryStyle(props.categoryName);
          final reporterReputation = userProvider.reputationCache[props.reportedBy];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(props.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    props.categoryName,
                    style: TextStyle(color: style.color, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: style.color.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: style.color.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // THIS IS THE CORRECTED SECTION
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Reported by ${props.reportedByUsername ?? 'Unknown User'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  
                  // This will display the reputation chip once it's loaded by the provider.
                  if (reporterReputation != null)
                    Chip(
                      avatar: Icon(Icons.shield_outlined, color: Colors.green.shade700, size: 14),
                      label: Text(
                        reporterReputation.reputationScore.toString(),
                        style: TextStyle(
                          color: Colors.green.shade800, 
                          fontSize: 12, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      backgroundColor: Colors.green.withOpacity(0.15),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              // END OF CORRECTED SECTION
              
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().add_jm().format(props.incidentDate.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const Divider(height: 32),
              Text(props.description ?? 'No description provided.', style: Theme.of(context).textTheme.bodyLarge),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.thumb_up, color: userVote == 'up' ? Colors.green : Theme.of(context).iconTheme.color),
                    onPressed: () => _handleVote(incidentProvider.voteOnIncident(_incidentId!, true)),
                  ),
                  Text('${props.upvotes ?? 0}'),
                  const SizedBox(width: 20),
                   IconButton(
                    icon: Icon(Icons.thumb_down, color: userVote == 'down' ? Colors.red : Theme.of(context).iconTheme.color),
                    onPressed: () => _handleVote(incidentProvider.voteOnIncident(_incidentId!, false)),
                  ),
                   Text('${props.downvotes ?? 0}'),
                ],
              ),
              const Divider(height: 32),
              Text('Comments', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _buildCommentSection(incidentProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommentSection(IncidentProvider provider) {
    final comments = provider.commentsByIncidentId[_incidentId] ?? [];
    final isLoading = provider.areCommentsLoading[_incidentId] ?? false;

    return Column(
      children: [
        if (isLoading && comments.isEmpty) const LoadingIndicator(),
        
        if (comments.isNotEmpty)
          for (final comment in comments)
            CommentWidget(comment: comment, incidentId: _incidentId!),

        if (!isLoading && comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Text("No comments yet. Be the first to comment!"),
          ),
        
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _onAddComment,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}