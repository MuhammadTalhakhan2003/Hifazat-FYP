# /api/views.py.

from django.shortcuts import get_object_or_404
from django.contrib.auth.models import User
from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.contrib.gis.geos import Polygon # For creating a polygon from bbox
# from django.contrib.gis.db.models.functions import X, Y # Import GeoDjango functions
from django.db import transaction # For atomic vote updates
from django.db.models import F # For atomic updates
from django.db.models import Count, Max, Min
from django.db.models.functions import ExtractHour, ExtractIsoWeekDay, TruncDay, TruncMonth, TruncYear
from django.utils import timezone
from datetime import timedelta

from rest_framework import generics, viewsets, status, permissions, mixins 
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_gis.filters import InBBoxFilter # For geographic filtering

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Profile, Category, Incident, IncidentMedia, Vote, Comment, Notification
from .serializers import (
    UserSerializer, RegisterSerializer, ProfileSerializer,
    CategorySerializer,
    IncidentMarkerSerializer, IncidentDetailSerializer, IncidentCreateUpdateSerializer,
    IncidentMediaSerializer, VoteCountSerializer,
    CommentSerializer, CommentCreateSerializer,
    NotificationSerializer
)
from .permissions import IsOwnerOrReadOnly # Custom permission (we'll create this)
# from django.contrib.gis.db.models.functions import X, Y

import numpy as np
from sklearn.neighbors import KernelDensity
from django.utils.dateparse import parse_datetime # For parsing date filters if needed
from django.db.models import Q # For complex queries

# --- Authentication Views ---

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,) # Anyone can register
    serializer_class = RegisterSerializer

# JWT views are provided by simplejwt, we just need to route them


# POST /auth/password-reset
# POST /auth/password-reset/confirm


# --- User Management Views ---

class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        # Returns the currently authenticated user's profile
        return self.request.user

    # PUT /users/me - handled by RetrieveUpdateAPIView


# POST /users/me/avatar - Likely needs a specific view to handle file upload and update profile.avatar_url

# --- Add this view ---
class UserReputationView(APIView):
    """
    Retrieves the calculated reputation score for a given user.
    """
    permission_classes = [permissions.AllowAny] # Or IsAuthenticated, depending on requirements

    def get(self, request, pk=None):
        # Find the user by primary key (pk comes from the URL)
        target_user = get_object_or_404(User, pk=pk)

        # Get the user's profile (handle case where profile might not exist, though our registration creates one)
        try:
            profile = target_user.profile
            reputation_score = profile.calculate_reputation()
        except Profile.DoesNotExist:
            # Handle users who might somehow exist without a profile
            # Or if calculate_reputation was on User model instead
            reputation_score = 0 # Default reputation if no profile?

        # Return the score
        return Response({
            "user_id": target_user.pk,
            "username": target_user.username,
            "reputation_score": reputation_score
        }, status=status.HTTP_200_OK)
# --- End of added view ---

# --- Category ViewSet ---
class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Provides list and detail views for Categories. Read-only for regular users.
    Admin can manage via /admin/ or a separate admin API endpoint.
    """
    queryset = Category.objects.filter(parent=None) # Start with top-level categories
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny] # Allow anyone to view categories

    # Optionally allow filtering or searching
    filter_backends = [SearchFilter]
    search_fields = ['name']

    # Action to get subcategories
    @action(detail=True, methods=['get'])
    def subcategories(self, request, pk=None):
        category = self.get_object()
        subcategories = category.subcategories.all()
        serializer = self.get_serializer(subcategories, many=True)
        return Response(serializer.data)


# --- Incident ViewSet ---
class IncidentViewSet(viewsets.ModelViewSet):
    """
    API endpoint for viewing, creating, updating, and deleting incidents.
    """
    queryset = Incident.objects.all().select_related('category', 'sub_category', 'created_by') # Optimize queries
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly] # Must be logged in to create, owner to edit/delete
    filter_backends = [InBBoxFilter, DjangoFilterBackend, SearchFilter, OrderingFilter] # Enable multiple filters
    # bbox_filter_field = 'location' # Specify the geometry field for InBBoxFilter
    # OR use bbox_filter_include_overlapping = True for features that overlap the bbox edge

    # -- Filtering Configuration --
    filterset_fields = {
        'category': ['exact', 'in'],
        'sub_category': ['exact', 'in'],
        'incident_date': ['gte', 'lte', 'date'], # Greater/less than or equal, exact date
        'city_name': ['exact', 'icontains'],
        'is_verified': ['exact'],
    }
    search_fields = ['title', 'description', 'city_name', 'category__name'] # Search across fields
    ordering_fields = ['incident_date', 'created_at', 'upvotes', 'downvotes'] # Allow ordering
    ordering = ['-incident_date'] # Default ordering

    # -- Serializer selection based on action --
    def get_serializer_class(self):
        if self.action == 'list':
             # Use marker serializer for map view/list (if bbox filter is primary use case)
             # Check if a bounding box filter is active?
             # if 'in_bbox' in self.request.query_params:
             #     return IncidentMarkerSerializer
             # Otherwise use a slightly more detailed list serializer if needed
             return IncidentMarkerSerializer # Keep it simple for list view for now
        if self.action in ['create', 'update', 'partial_update']:
            return IncidentCreateUpdateSerializer
        return IncidentDetailSerializer # For retrieve (detail view)

    # Add context (request) to serializer for create/update
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context.update({"request": self.request})
        return context

    # Override perform_create to set the created_by field
    def perform_create(self, serializer):
        # Set created_by from the request user, passed via context
        serializer.save() # Location is handled within the serializer now

    # Override perform_update to potentially handle location update logic if not in serializer
    # def perform_update(self, serializer):
    #     serializer.save() # Location update handled in serializer

    # GET /incidents/ - List handled by ViewSet
    # POST /incidents/ - Create handled by ViewSet
    # GET /incidents/{id}/ - Retrieve handled by ViewSet
    # PUT /incidents/{id}/ - Update handled by ViewSet
    # DELETE /incidents/{id}/ - Destroy handled by ViewSet

    # -- Aggregated statistics for the analytics dashboard --
    # GET /incidents/stats/?period=week|month|year|all
    STATS_PERIOD_DAYS = {'week': 7, 'month': 30, 'year': 365}

    @action(detail=False, methods=['get'], permission_classes=[permissions.AllowAny], url_path='stats')
    def stats(self, request):
        period = request.query_params.get('period', 'all')
        if period not in (*self.STATS_PERIOD_DAYS, 'all'):
            return Response({'detail': "period must be one of: week, month, year, all"},
                            status=status.HTTP_400_BAD_REQUEST)

        base = Incident.objects.all()
        date_range = base.aggregate(earliest=Min('incident_date'), latest=Max('incident_date'))

        qs, previous_total = base, None
        if period in self.STATS_PERIOD_DAYS:
            days = timedelta(days=self.STATS_PERIOD_DAYS[period])
            start = timezone.now() - days
            qs = base.filter(incident_date__gte=start)
            previous_total = base.filter(incident_date__gte=start - days, incident_date__lt=start).count()

        # Bucket size for the timeline chart.
        trunc = {'week': TruncDay, 'month': TruncDay, 'year': TruncMonth}.get(period, TruncYear)
        timeline = (qs.annotate(bucket=trunc('incident_date')).values('bucket')
                    .annotate(count=Count('id')).order_by('bucket'))

        by_hour = [0] * 24
        for row in qs.annotate(hour=ExtractHour('incident_date')).values('hour').annotate(count=Count('id')):
            by_hour[row['hour']] = row['count']

        by_weekday = [0] * 7  # Monday first
        for row in qs.annotate(day=ExtractIsoWeekDay('incident_date')).values('day').annotate(count=Count('id')):
            by_weekday[row['day'] - 1] = row['count']

        by_category = qs.values('category__name').annotate(count=Count('id')).order_by('-count')
        cities = qs.exclude(city_name__isnull=True).exclude(city_name='')
        top_cities = cities.values('city_name').annotate(count=Count('id')).order_by('-count')[:8]

        return Response({
            'period': period,
            'total': qs.count(),
            'previous_total': previous_total,
            'verified': qs.filter(is_verified=True).count(),
            'cities_count': cities.values('city_name').distinct().count(),
            'earliest_incident_date': date_range['earliest'],
            'latest_incident_date': date_range['latest'],
            'by_category': [{'name': r['category__name'], 'count': r['count']} for r in by_category],
            'top_cities': [{'name': r['city_name'], 'count': r['count']} for r in top_cities],
            'timeline': [{'date': r['bucket'], 'count': r['count']} for r in timeline],
            'by_hour': by_hour,
            'by_weekday': by_weekday,
        })

    # -- Custom Actions for Voting --
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def upvote(self, request, pk=None):
        return self._vote(request, pk, 'up')

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def downvote(self, request, pk=None):
        return self._vote(request, pk, 'down')

    def _vote(self, request, pk, vote_type):
        incident = self.get_object()
        user = request.user
        vote, created = Vote.objects.get_or_create(user=user, incident=incident, defaults={'vote_type': vote_type})

        with transaction.atomic():
            incident = Incident.objects.select_for_update().get(pk=incident.pk) # Lock row
            if created:
                # New vote
                if vote_type == 'up':
                    incident.upvotes = F('upvotes') + 1
                else:
                    incident.downvotes = F('downvotes') + 1
            elif vote.vote_type != vote_type:
                # Change existing vote
                if vote_type == 'up':
                    incident.upvotes = F('upvotes') + 1
                    incident.downvotes = F('downvotes') - 1
                else: # Changing to downvote
                    incident.upvotes = F('upvotes') - 1
                    incident.downvotes = F('downvotes') + 1
                vote.vote_type = vote_type
                vote.save()
            else:
                # User clicking the same vote type again - remove vote
                if vote_type == 'up':
                    incident.upvotes = F('upvotes') - 1
                else:
                    incident.downvotes = F('downvotes') - 1
                vote.delete()
                incident.save()
                # Refresh incident state after potential delete
                incident.refresh_from_db()
                serializer = VoteCountSerializer({'upvotes': incident.upvotes, 'downvotes': incident.downvotes, 'current_user_vote': None})
                return Response(serializer.data, status=status.HTTP_200_OK) # Indicate vote removed

            incident.save()
            # Refresh incident state after F() expressions
            incident.refresh_from_db()
            serializer = VoteCountSerializer({'upvotes': incident.upvotes, 'downvotes': incident.downvotes, 'current_user_vote': vote.vote_type})
            return Response(serializer.data, status=status.HTTP_200_OK if created else status.HTTP_200_OK) # 201 for new, 200 for update


    # GET /incidents/{id}/votes - Get vote statistics
    @action(detail=True, methods=['get'])
    def votes(self, request, pk=None):
        incident = self.get_object()
        current_vote = None
        if request.user.is_authenticated:
            try:
                vote = Vote.objects.get(incident=incident, user=request.user)
                current_vote = vote.vote_type
            except Vote.DoesNotExist:
                pass
        serializer = VoteCountSerializer({'upvotes': incident.upvotes, 'downvotes': incident.downvotes, 'current_user_vote': current_vote})
        return Response(serializer.data)


    # -- Actions for Media --
    # POST /incidents/{id}/media

    # Requires handling file uploads (using FileField/ImageField in model & serializer)

    # DELETE /incidents/{id}/media/{media_id}



# --- Comments ViewSet ---
# We use a standard ViewSet for Comments, but list/create are often nested under Incidents.
class CommentViewSet(viewsets.ModelViewSet):
    """
    API endpoint for comments. List/Create are often accessed via Incident endpoint.
    Update/Delete work on /comments/{id}/.
    """
    queryset = Comment.objects.all().select_related('user', 'incident') # Optimize
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'create':
            return CommentCreateSerializer
        return CommentSerializer # Use full serializer for list/retrieve/update

        # --- ADD THIS METHOD ---
    def get_queryset(self):
        """
        Overrides the default queryset to filter comments based on the
        'incident_pk' URL keyword argument if it exists (i.e., when accessed
        via the nested route like /incidents/{incident_pk}/comments/).
        """
        # Start with all comments, properly ordered and pre-fetching related users
        queryset = Comment.objects.select_related('user').order_by('created_at')

        # Get the incident primary key from the URL kwargs provided by the nested router
        incident_pk = self.kwargs.get('incident_pk')

        if incident_pk is not None:
            # If incident_pk exists in the URL, filter the comments by it
            queryset = queryset.filter(incident__pk=incident_pk)
            # You could raise a 404 here if the incident itself doesn't exist,
            # but filtering returning an empty list is often acceptable too.
            # get_object_or_404(Incident, pk=incident_pk) # Optional: Ensure incident exists

        # If not accessed via nested route (e.g., /api/comments/), this will return all comments.
        # You might want different behavior for the top-level /api/comments/ endpoint
        # (e.g., disallow list view, or require filtering by user, etc.)

        return queryset
    # --- END OF ADDED METHOD ---

    def perform_create(self, serializer):
        # Get incident from URL if nested, or maybe from request data (less RESTful)
        # This setup assumes non-nested creation or incident_id passed in data,
        # better approach is nesting URLs. We'll adjust in URL setup.
        incident_id = self.request.data.get('incident') or self.kwargs.get('incident_pk') # Check both data and URL kwargs
        incident = get_object_or_404(Incident, pk=incident_id)
        serializer.save(user=self.request.user, incident=incident)

    def create(self, request, *args, **kwargs):
        # Validate with the create serializer, but respond with the full comment
        # (id, user, created_at, ...) so clients can display it immediately.
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        comment_serializer = CommentSerializer(serializer.instance, context=self.get_serializer_context())
        headers = self.get_success_headers(comment_serializer.data)
        return Response(comment_serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    # PUT /comments/{comment_id}/ - Update handled by ViewSet
    # DELETE /comments/{comment_id}/ - Destroy handled by ViewSet

    # -- Custom Actions for Comments --

    # POST /comments/{comment_id}/reply
    @action(detail=True, methods=['post'], serializer_class=CommentCreateSerializer)
    def reply(self, request, pk=None):
        parent_comment = self.get_object()
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(
            user=request.user,
            incident=parent_comment.incident,
            parent_comment=parent_comment # Set the parent
        )
        # Return the created reply using the standard CommentSerializer
        reply_serializer = CommentSerializer(serializer.instance, context=self.get_serializer_context())
        headers = self.get_success_headers(reply_serializer.data)
        return Response(reply_serializer.data, status=status.HTTP_201_CREATED, headers=headers)


    # POST /comments/{comment_id}/report
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def report(self, request, pk=None):
        comment = self.get_object()
        # TODO: Implement reporting logic
        # - Create a 'Report' model to track reports?
        # - Send notification to admins?
        # - Check if user already reported?
        print(f"User {request.user.username} reported comment {comment.id}: '{comment.content[:50]}...'") # Placeholder
        return Response({"message": "Comment reported successfully."}, status=status.HTTP_200_OK)


# --- Predictive Analytics Views (Placeholders) ---

class PredictRiskView(APIView):
    permission_classes = [permissions.AllowAny] # Or IsAuthenticated

    def get(self, request):
        # TODO: Implement AI/ML model integration
        # - Get location query params (lat, lon, radius?)
        # - Query relevant historical incident data
        # - Pass data to the prediction model
        # - Return risk score/level
        lat = request.query_params.get('lat')
        lon = request.query_params.get('lon')
        if not lat or not lon:
            return Response({"error": "Latitude (lat) and Longitude (lon) are required."}, status=status.HTTP_400_BAD_REQUEST)

        # Placeholder response
        return Response({
            "latitude": float(lat),
            "longitude": float(lon),
            "predicted_risk_level": 3, # Example: Medium risk
            "confidence": 0.75,
             "message": "Prediction model not yet implemented."
        })

class PredictHotspotsView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        # TODO: Implement hotspot prediction logic
        # - Get area/bbox query params
        # - Query historical data
        # - Use clustering or density analysis (or ML model)
        # - Return GeoJSON FeatureCollection of hotspot areas/points
        bbox_str = request.query_params.get('bbox') # e.g., "min_lon,min_lat,max_lon,max_lat"

        # Placeholder response
        return Response({
            "type": "FeatureCollection",
            "features": [
                # Example hotspot feature
                {
                    "type": "Feature",
                    "geometry": { "type": "Point", "coordinates": [73.05, 33.68] }, # Example coords
                    "properties": { "intensity": 0.8, "crime_type": "Theft" }
                }
            ],
            "message": "Hotspot prediction model not yet implemented."
        })


# --- Notifications ViewSet ---
class NotificationViewSet(viewsets.GenericViewSet,
                          mixins.ListModelMixin,
                          mixins.RetrieveModelMixin): # No create/update/delete for users directly
    """
    API endpoint for user notifications. Read-only for users.
    Marking as read/deleting might be handled by custom actions.
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Return only notifications for the current logged-in user
        return Notification.objects.filter(user=self.request.user)

    # GET /notifications/ - List handled by ListModelMixin

    @action(detail=True, methods=['put'])
    def read(self, request, pk=None):
        notification = self.get_object()
        # Basic check: ensure the notification belongs to the user making the request
        if notification.user != request.user:
             return Response(status=status.HTTP_403_FORBIDDEN) # Or 404? User shouldn't see others' notifications anyway

        notification.is_read = True
        notification.save(update_fields=['is_read'])
        serializer = self.get_serializer(notification)
        return Response(serializer.data)

    # TODO: Implement DELETE /notifications/{id}/
    # Needs a destroy method or action, checking permissions


# --- Administration Views ---

class AdminVerifyIncidentView(APIView):
    permission_classes = [permissions.IsAdminUser] # Only admins

    def post(self, request, incident_id):
        incident = get_object_or_404(Incident, pk=incident_id)
        # You might want toggle logic, or separate verify/unverify endpoints
        incident.is_verified = True
        incident.save(update_fields=['is_verified'])
        # TODO: Optionally send a notification to the reporter
        return Response({"message": f"Incident {incident_id} verified successfully."}, status=status.HTTP_200_OK)


# TODO: Admin Category Management View (PUT /admin/categories) - Might use CategoryViewSet with admin perms
# TODO: Admin Analytics View (GET /admin/analytics) - Custom view summarizing data

class PredictHotspotsView(APIView):
    permission_classes = [permissions.AllowAny] # Or IsAuthenticated

    def get(self, request):
        """
        Predicts crime hotspots using Kernel Density Estimation.
        Accepts query parameters for filtering incidents:
        - bbox (min_lon,min_lat,max_lon,max_lat): Bounding box for the area of interest. REQUIRED.
        - category (id): Filter by category ID.
        - start_date (YYYY-MM-DD): Filter incidents from this date.
        - end_date (YYYY-MM-DD): Filter incidents up to this date.
        - bandwidth (float): Bandwidth for KDE. Optional, defaults to a heuristic.
        - grid_size (int): Number of points along each axis of the evaluation grid. Optional, defaults to 100.
        """
        bbox_str = request.query_params.get('bbox')
        if not bbox_str:
            return Response({"error": "Bounding box (bbox) is a required parameter (format: min_lon,min_lat,max_lon,max_lat)."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            min_lon, min_lat, max_lon, max_lat = map(float, bbox_str.split(','))
        except ValueError:
            return Response({"error": "Invalid bbox format. Use: min_lon,min_lat,max_lon,max_lat"},
                            status=status.HTTP_400_BAD_REQUEST)

        # --- Fetch Incident Data ---
        queryset = Incident.objects.all()

        # Apply filters from query parameters
        category_id = request.query_params.get('category')
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')

        if category_id:
            queryset = queryset.filter(category_id=category_id)
        if start_date_str:
            start_date = parse_datetime(start_date_str + "T00:00:00Z") # Assume start of day, UTC
            if start_date:
                queryset = queryset.filter(incident_date__gte=start_date)
        if end_date_str:
            end_date = parse_datetime(end_date_str + "T23:59:59Z") # Assume end of day, UTC
            if end_date:
                queryset = queryset.filter(incident_date__lte=end_date)

        # Filter by bounding box (using PostGIS functions for efficiency is better, but this is simpler for now)
        # For production, use a spatial query: Incident.objects.filter(location__within=polygon_from_bbox)
        # Here, we fetch then filter in Python, which is less efficient for large datasets.
        incidents_in_area = []
        # If you have many incidents, it's better to filter in DB first
        # For now, let's fetch all based on other filters, then Python filter by bbox
        # This is a SIMPLIFICATION. For production, use DB spatial queries.
        all_filtered_incidents = queryset.values_list('location', flat=True) # Get Point objects

        locations = []
        for point in all_filtered_incidents:
            if point and (min_lon <= point.x <= max_lon and min_lat <= point.y <= max_lat):
                locations.append([point.x, point.y]) # lon, lat for KDE

        if not locations:
            return Response({"message": "No incidents found in the specified area and filters to compute hotspots."},
                            status=status.HTTP_200_OK)

        X_train = np.array(locations) # shape (n_incidents, 2)

        # --- Kernel Density Estimation ---
        # Bandwidth: This is a critical parameter.
        # Scott's rule or Silverman's rule are common heuristics, or cross-validation.
        # A smaller bandwidth makes the estimate more spiky, a larger one makes it smoother.
        # Example: 0.01 degrees is roughly 1.1km. Adjust based on your data scale.
        bandwidth_str = request.query_params.get('bandwidth')
        bandwidth = float(bandwidth_str) if bandwidth_str else 0.01 # Default bandwidth in degrees

        try:
            kde = KernelDensity(kernel='gaussian', bandwidth=bandwidth).fit(X_train)
        except Exception as e:
             return Response({"error": f"KDE fitting error: {str(e)}. Try adjusting bandwidth or ensure sufficient data points."},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


        # --- Evaluate KDE on a Grid ---
        # Create a grid of points covering the bounding box
        grid_size_str = request.query_params.get('grid_size')
        grid_size = int(grid_size_str) if grid_size_str else 100 # Number of points along each axis

        xx, yy = np.meshgrid(np.linspace(min_lon, max_lon, grid_size),
                             np.linspace(min_lat, max_lat, grid_size))
        xy_eval = np.vstack([xx.ravel(), yy.ravel()]).T # Grid points to evaluate

        # Calculate log-density (KDE scores are log probabilities)
        try:
            log_dens = kde.score_samples(xy_eval)
            densities = np.exp(log_dens)  # Convert log-density to density
        except Exception as e:
             return Response({"error": f"KDE scoring error: {str(e)}. This can happen with very few data points or extreme bandwidth."},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


        # --- Format Output ---
        # Return points on the grid with their density scores.
        # Frontend can then visualize these (e.g., using a heatmap library with these densities as intensities).
        hotspot_points = []
        # Normalize densities for easier visualization if desired, or filter by a threshold
        # For simplicity, we return all grid points and their raw densities.
        # A good frontend visualization will typically normalize or use a threshold.
        min_density_threshold = densities.mean() # Example: only show points above average density

        for i in range(len(xy_eval)):
            if densities[i] > min_density_threshold: # Only include "hotter" points
                hotspot_points.append({
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [xy_eval[i, 0], xy_eval[i, 1]] # lon, lat
                    },
                    "properties": {
                        "density": float(densities[i]), # Ensure it's a standard float
                        # "log_density": float(log_dens[i]) # Optionally return log density
                    }
                })
        
        if not hotspot_points:
             return Response({
                 "message": "No significant hotspots detected above the threshold.",
                 "bbox": [min_lon, min_lat, max_lon, max_lat],
                 "filter_incident_count": len(locations),
                 "threshold_used": float(min_density_threshold)
                }, status=status.HTTP_200_OK)


        return Response({
            "type": "FeatureCollection",
            "features": hotspot_points,
            "metadata": {
                "bbox": [min_lon, min_lat, max_lon, max_lat],
                "bandwidth_used": bandwidth,
                "grid_size": grid_size,
                "filter_incident_count": len(locations),
                "threshold_used": float(min_density_threshold)
            }
        }, status=status.HTTP_200_OK)