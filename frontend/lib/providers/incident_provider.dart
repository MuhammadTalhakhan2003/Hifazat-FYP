import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/comment.dart';
import 'package:hifazat_app/api/models/incident.dart';
import 'package:hifazat_app/api/models/vote_response.dart';
import 'package:hifazat_app/api/services/comment_service.dart';
import 'package:hifazat_app/api/services/incident_service.dart';
import 'package:hifazat_app/api/models/paginated_result.dart';

class IncidentProvider with ChangeNotifier {
  final IncidentService _incidentService = IncidentService();
  final CommentService _commentService = CommentService();

  // --- STATE VARIABLES ---


  // Data for different UI parts
  List<Incident> _mapIncidents = [];
  List<Incident> get mapIncidents => _mapIncidents;

  List<Incident> _incidentList = [];
  List<Incident> get incidentList => _incidentList;

  
  // State for a single selected incident (for detail screen)
  Incident? _selectedIncident;
  Incident? get selectedIncident => _selectedIncident;
  
  // State for votes and comments, keyed by incident ID
  final Map<int, VoteResponse> _votesByIncidentId = {};
  Map<int, VoteResponse> get votesByIncidentId => _votesByIncidentId;

  final Map<int, List<Comment>> _commentsByIncidentId = {};
  Map<int, List<Comment>> get commentsByIncidentId => _commentsByIncidentId;
  
  final Map<int, bool> _areCommentsLoading = {};
  Map<int, bool> get areCommentsLoading => _areCommentsLoading;
  
  final Map<int, String?> _userVoteStatus = {};
  Map<int, String?> get userVoteStatus => _userVoteStatus;

  // Pagination and loading state
  Map<String, dynamic> _currentFilters = {};
  int _currentPage = 1;
  bool _hasMoreIncidents = true;
  bool get hasMoreIncidents => _hasMoreIncidents;
  bool _isFetchingMore = false;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- DATA FETCHING METHODS ---

  

  Future<void> fetchMapIncidents() async {
    _isLoading = true;
    notifyListeners();
    try {
      final PaginatedResult<Incident> result = await _incidentService.getIncidentsPaginated(queryParams: {'page_size': 200});
      _mapIncidents = result.results;
    } catch (e) {
      _errorMessage = "Failed to load incidents on map.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchIncidentList({bool isRefresh = false, Map<String, dynamic>? newFilters}) async {
    if (_isFetchingMore && !isRefresh) return;
    if (isRefresh) {
      _incidentList = [];
      _currentPage = 1;
      _hasMoreIncidents = true;
      _currentFilters = newFilters ?? {};
      _commentsByIncidentId.clear();
      _userVoteStatus.clear();
    }
    if (!_hasMoreIncidents) return;
    if (_incidentList.isEmpty) _isLoading = true; else _isFetchingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = {..._currentFilters, 'page': _currentPage};
      final PaginatedResult<Incident> paginatedResult = await _incidentService.getIncidentsPaginated(queryParams: queryParams);
      
      _incidentList.addAll(paginatedResult.results);
      _hasMoreIncidents = paginatedResult.hasNext;
      
      if (_hasMoreIncidents) _currentPage++;
      
    } catch (e) {
      _errorMessage = "Failed to load incidents.";
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }
  
  Future<void> fetchIncidentDetails(int id) async {
    _isLoading = true;
    _selectedIncident = null;
    notifyListeners();
    try {
      _selectedIncident = await _incidentService.getIncidentById(id);
      if (_selectedIncident != null) {
        _votesByIncidentId[id] = VoteResponse(
          upvotes: _selectedIncident!.properties.upvotes ?? 0,
          downvotes: _selectedIncident!.properties.downvotes ?? 0,
        );
      }
    } catch (e) {
      _errorMessage = "Failed to load incident details.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchComments(int incidentId, {bool force = false}) async {
    if (_commentsByIncidentId.containsKey(incidentId) && !force) return;
    _areCommentsLoading[incidentId] = true;
    notifyListeners();
    try {
      final comments = await _commentService.getCommentsForIncident(incidentId);
      _commentsByIncidentId[incidentId] = comments;
    } catch (e) {
      debugPrint("Failed to fetch comments for incident $incidentId: $e");
    } finally {
      _areCommentsLoading[incidentId] = false;
      notifyListeners();
    }
  }

  // --- ACTION METHODS ---
  
  Future<bool> createIncident(IncidentCreateRequest request) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _incidentService.createIncident(request);
      await fetchMapIncidents();
      await fetchIncidentList(isRefresh: true);
      return true;
    } catch (e) {
      _errorMessage = "Failed to report incident.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> voteOnIncident(int incidentId, bool isUpvote) async {
    try {
      final voteResponse = isUpvote
        ? await _incidentService.upvoteIncident(incidentId)
        : await _incidentService.downvoteIncident(incidentId);
      
      _updateIncidentData(incidentId, voteResponse);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Voting failed: $e");
      return false;
    }
  }

  Future<bool> addCommentToIncident(int incidentId, String content) async {
    final Comment newComment;
    try {
      newComment = await _commentService.createComment(incidentId, CommentCreateRequest(content: content));
    } on DioException catch (e) {
      debugPrint("Failed to add comment: ${e.message}");
      return false;
    } catch (e) {
      // The comment was saved but the response couldn't be parsed; reload the thread instead.
      debugPrint("Comment created but response unreadable ($e); reloading comments.");
      await fetchComments(incidentId, force: true);
      return true;
    }

    // Comments are listed oldest first, so the new one goes at the end.
    final currentComments = _commentsByIncidentId[incidentId] ?? [];
    _commentsByIncidentId[incidentId] = [...currentComments, newComment];
    notifyListeners();
    return true;
  }

  // --- HELPER ---
  void _updateIncidentData(int incidentId, VoteResponse voteResponse) {
    // Update the incident in the main list
    final listIndex = _incidentList.indexWhere((i) => i.id == incidentId);
    if (listIndex != -1) {
      final oldIncident = _incidentList[listIndex];
      _incidentList[listIndex] = oldIncident.copyWith(
        properties: oldIncident.properties.copyWith(
          upvotes: voteResponse.upvotes,
          downvotes: voteResponse.downvotes,
        ),
      );
    }
    // Update the incident if it's the currently selected one for the detail page
    if (_selectedIncident?.id == incidentId) {
      _selectedIncident = _selectedIncident!.copyWith(
        properties: _selectedIncident!.properties.copyWith(
          upvotes: voteResponse.upvotes,
          downvotes: voteResponse.downvotes,
        ),
      );
    }
    // Update the vote status for the specific incident
    _userVoteStatus[incidentId] = voteResponse.currentUserVote;
  }

    // NEW METHOD
  Future<bool> deleteComment(int incidentId, int commentId) async {
    try {
      await _commentService.deleteComment(commentId);
      
      // Remove the comment from the local state for instant UI update
      final comments = _commentsByIncidentId[incidentId];
      if (comments != null) {
        comments.removeWhere((comment) => comment.id == commentId);
        _commentsByIncidentId[incidentId] = List.from(comments); // Create new list to trigger listeners
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint("Failed to delete comment: $e");
      // Optionally show a snackbar to the user about the failure
      return false;
    }
  }
}