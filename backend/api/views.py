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
import logging
import secrets

from django.contrib.auth.hashers import make_password, check_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.utils.html import escape
from rest_framework.exceptions import ValidationError
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken

logger = logging.getLogger(__name__)

from rest_framework import generics, viewsets, status, permissions, mixins 
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_gis.filters import InBBoxFilter # For geographic filtering

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Profile, Category, Incident, IncidentMedia, Vote, Comment, Notification, PasswordResetCode
from .serializers import (
    UserSerializer, RegisterSerializer, ProfileSerializer,
    CategorySerializer,
    IncidentMarkerSerializer, IncidentDetailSerializer, IncidentCreateUpdateSerializer,
    IncidentMediaSerializer, VoteCountSerializer,
    CommentSerializer, CommentCreateSerializer,
    NotificationSerializer,
    PasswordResetRequestSerializer, PasswordResetVerifySerializer, PasswordResetConfirmSerializer,
)
from .permissions import IsOwnerOrReadOnly # Custom permission (we'll create this)
# from django.contrib.gis.db.models.functions import X, Y

import numpy as np
from scipy.ndimage import gaussian_filter
from django.db import connection
from django.utils.dateparse import parse_datetime # For parsing date filters if needed
from django.db.models import Q # For complex queries

# --- Authentication Views ---

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,) # Anyone can register
    serializer_class = RegisterSerializer

# JWT views are provided by simplejwt, we just need to route them


# --- Password Reset (forgot password) Views ---
# 1. POST /auth/password-reset/          {email}                     -> emails a 6-digit code
# 2. POST /auth/password-reset/verify/   {email, code}               -> checks the code
# 3. POST /auth/password-reset/confirm/  {email, code, new_password, new_password2} -> sets the password

RESET_CODE_TTL = timedelta(minutes=10)
RESET_CODE_RESEND_COOLDOWN = timedelta(seconds=60)
RESET_CODE_MAX_ATTEMPTS = 5
INVALID_CODE_MESSAGE = 'This code is invalid or has expired. Please request a new one.'


def _send_reset_code_email(user, code):
    minutes = int(RESET_CODE_TTL.total_seconds() // 60)
    name = user.first_name or user.username
    subject = 'Your Hifazat password reset code'
    text = (
        f"Hi {name},\n\n"
        f"We received a request to reset your Hifazat password.\n\n"
        f"Your verification code is: {code}\n\n"
        f"This code expires in {minutes} minutes. If you didn't request this, "
        f"you can safely ignore this email; your password won't change.\n\n"
        f"- The Hifazat Team"
    )
    html = f"""
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;color:#1D1D1F">
      <div style="background:#0F3460;color:#fff;padding:20px 24px;border-radius:8px 8px 0 0">
        <h2 style="margin:0">Hifazat</h2>
      </div>
      <div style="border:1px solid #E6E8EE;border-top:none;padding:24px;border-radius:0 0 8px 8px">
        <p>Hi {escape(name)},</p>
        <p>We received a request to reset your Hifazat password. Use this code to continue:</p>
        <p style="font-size:32px;font-weight:bold;letter-spacing:8px;text-align:center;
                  background:#F5F5F7;padding:16px;border-radius:8px;margin:24px 0">{code}</p>
        <p>This code expires in {minutes} minutes.</p>
        <p style="color:#666;font-size:13px">If you didn't request this, you can safely ignore this email;
          your password won't change.</p>
      </div>
    </div>
    """
    send_mail(subject, text, None, [user.email], html_message=html)


def _get_valid_reset_code(email, code):
    """Returns the active PasswordResetCode for this email if `code` matches it,
    otherwise raises a ValidationError. Wrong guesses count towards the attempt limit."""
    reset = (PasswordResetCode.objects
             .filter(user__email__iexact=email, user__is_active=True,
                     is_used=False, expires_at__gt=timezone.now())
             .select_related('user')
             .first())
    if reset is None or reset.attempts >= RESET_CODE_MAX_ATTEMPTS:
        raise ValidationError({'code': [INVALID_CODE_MESSAGE]})

    if not check_password(code, reset.code_hash):
        PasswordResetCode.objects.filter(pk=reset.pk).update(attempts=F('attempts') + 1)
        remaining = RESET_CODE_MAX_ATTEMPTS - reset.attempts - 1
        if remaining <= 0:
            raise ValidationError({'code': [INVALID_CODE_MESSAGE]})
        raise ValidationError({'code': [f'Incorrect code. {remaining} attempt(s) left.']})
    return reset


class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []  # A stale token on the device must not block this

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']

        user = (User.objects.filter(email__iexact=email, is_active=True)
                .order_by(F('last_login').desc(nulls_last=True)).first())
        if user:
            now = timezone.now()
            sent_recently = user.password_reset_codes.filter(
                created_at__gt=now - RESET_CODE_RESEND_COOLDOWN).exists()
            if not sent_recently:
                code = f"{secrets.randbelow(10**6):06d}"
                with transaction.atomic():
                    # Only the newest code is ever valid
                    user.password_reset_codes.filter(is_used=False).update(is_used=True)
                    reset = PasswordResetCode.objects.create(
                        user=user, code_hash=make_password(code), expires_at=now + RESET_CODE_TTL)
                try:
                    _send_reset_code_email(user, code)
                except Exception:
                    logger.exception("Failed to send password reset email to user %s", user.pk)
                    reset.delete()
                    return Response({'detail': "We couldn't send the email right now. Please try again later."},
                                    status=status.HTTP_503_SERVICE_UNAVAILABLE)

        # Same response whether or not the email is registered, so accounts can't be probed
        return Response({'detail': 'If an account exists for this email, a 6-digit code has been sent to it.'},
                        status=status.HTTP_200_OK)


class PasswordResetVerifyView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = PasswordResetVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        _get_valid_reset_code(serializer.validated_data['email'], serializer.validated_data['code'])
        return Response({'detail': 'Code verified.'}, status=status.HTTP_200_OK)


class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        reset = _get_valid_reset_code(data['email'], data['code'])
        user = reset.user
        try:
            validate_password(data['new_password'], user)
        except DjangoValidationError as e:
            raise ValidationError({'new_password': list(e.messages)})

        with transaction.atomic():
            user.set_password(data['new_password'])
            user.save(update_fields=['password'])
            reset.is_used = True
            reset.save(update_fields=['is_used'])
            # Sign the user out everywhere: blacklist every refresh token issued before the reset
            for token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=token)

        return Response({'detail': 'Your password has been reset. You can now log in.'},
                        status=status.HTTP_200_OK)


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
    """
    GET /predict/hotspots/?bbox=min_lon,min_lat,max_lon,max_lat

    Predicts incident hotspots with a binned Gaussian Kernel Density Estimate:
    PostGIS counts incidents per grid cell inside the (padded) bbox in one query,
    then the counts are smoothed with a Gaussian kernel. This is the standard fast
    approximation of KDE and stays quick with 100k+ incidents, unlike fitting a
    KDE over every raw point in Python.

    Optional params:
    - category (id), start_date / end_date (YYYY-MM-DD): filter incidents
    - bandwidth (degrees): kernel width; defaults to scale with the bbox (zoom level)
    - grid_size (int, 20-200): cells along each axis, default 96

    Always returns a GeoJSON FeatureCollection. Each feature is a grid cell centre
    with a `density` normalised to 0..1 (1 = hottest cell in view).
    """
    permission_classes = [permissions.AllowAny]

    PAD_RATIO = 0.1              # Count incidents slightly outside the view so edges aren't cut off
    DEFAULT_SIGMA_CELLS = 1.5    # Kernel width in grid cells when no bandwidth is given
    MIN_BANDWIDTH_DEG = 0.003    # ~300 m, so zooming far in doesn't shrink hotspots to dots
    MIN_DENSITY = 0.12           # Drop cells cooler than this (after normalising) to keep payloads small

    def get(self, request):
        bbox_str = request.query_params.get('bbox')
        if not bbox_str:
            return Response({"error": "Bounding box (bbox) is a required parameter (format: min_lon,min_lat,max_lon,max_lat)."},
                            status=status.HTTP_400_BAD_REQUEST)
        try:
            min_lon, min_lat, max_lon, max_lat = map(float, bbox_str.split(','))
            grid_size = min(max(int(request.query_params.get('grid_size', 96)), 20), 200)
            bandwidth = request.query_params.get('bandwidth')
            bandwidth = float(bandwidth) if bandwidth else None
        except ValueError:
            return Response({"error": "Invalid parameters. bbox format: min_lon,min_lat,max_lon,max_lat"},
                            status=status.HTTP_400_BAD_REQUEST)
        if min_lon >= max_lon or min_lat >= max_lat:
            return Response({"error": "Invalid bbox: min values must be smaller than max values."},
                            status=status.HTTP_400_BAD_REQUEST)

        # Map views can extend past the valid coordinate range
        min_lon, max_lon = max(min_lon, -180.0), min(max_lon, 180.0)
        min_lat, max_lat = max(min_lat, -90.0), min(max_lat, 90.0)

        pad_lon = (max_lon - min_lon) * self.PAD_RATIO
        pad_lat = (max_lat - min_lat) * self.PAD_RATIO
        grid_min_lon, grid_max_lon = min_lon - pad_lon, max_lon + pad_lon
        grid_min_lat, grid_max_lat = min_lat - pad_lat, max_lat + pad_lat
        cell_lon = (grid_max_lon - grid_min_lon) / grid_size
        cell_lat = (grid_max_lat - grid_min_lat) / grid_size

        # --- 1. Count incidents per grid cell in the database ---
        where = ["g && ST_MakeEnvelope(%s, %s, %s, %s, 4326)"]
        params = [grid_min_lon, grid_min_lat, grid_max_lon, grid_max_lat]

        category_id = request.query_params.get('category')
        if category_id:
            where.append("category_id = %s")
            params.append(category_id)
        start_date = parse_datetime(request.query_params.get('start_date', '') + "T00:00:00Z")
        if start_date:
            where.append("incident_date >= %s")
            params.append(start_date)
        end_date = parse_datetime(request.query_params.get('end_date', '') + "T23:59:59Z")
        if end_date:
            where.append("incident_date <= %s")
            params.append(end_date)

        sql = f"""
            SELECT LEAST(FLOOR((ST_X(g) - %s) / %s)::int, %s) AS ix,
                   LEAST(FLOOR((ST_Y(g) - %s) / %s)::int, %s) AS iy,
                   COUNT(*)
            FROM (SELECT location::geometry AS g, category_id, incident_date
                  FROM {Incident._meta.db_table}) AS incidents
            WHERE {" AND ".join(where)}
            GROUP BY ix, iy
        """
        last = grid_size - 1
        with connection.cursor() as cursor:
            cursor.execute(sql, [grid_min_lon, cell_lon, last, grid_min_lat, cell_lat, last] + params)
            rows = cursor.fetchall()

        counts = np.zeros((grid_size, grid_size))  # [iy, ix]
        for ix, iy, count in rows:
            counts[iy, ix] = count
        incident_count = int(counts.sum())

        # --- 2. Gaussian kernel smoothing = binned KDE ---
        bandwidth_deg = bandwidth if bandwidth else self.DEFAULT_SIGMA_CELLS * max(cell_lon, cell_lat)
        bandwidth_deg = max(bandwidth_deg, self.MIN_BANDWIDTH_DEG)
        density = gaussian_filter(counts, sigma=(bandwidth_deg / cell_lat, bandwidth_deg / cell_lon), mode='constant')

        # --- 3. Normalise and keep the hot cells inside the view ---
        features = []
        peak = density.max()
        if peak > 0:
            # sqrt spreads the range so smaller hotspots stay visible next to big-city peaks
            normalised = np.sqrt(density / peak)
            for iy, ix in zip(*np.nonzero(normalised >= self.MIN_DENSITY)):
                lon = grid_min_lon + (ix + 0.5) * cell_lon
                lat = grid_min_lat + (iy + 0.5) * cell_lat
                if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
                    features.append({
                        "type": "Feature",
                        "geometry": {"type": "Point", "coordinates": [round(lon, 5), round(lat, 5)]},
                        "properties": {"density": round(float(normalised[iy, ix]), 3)},
                    })

        return Response({
            "type": "FeatureCollection",
            "features": features,
            "metadata": {
                "bbox": [min_lon, min_lat, max_lon, max_lat],
                "method": "binned gaussian kde",
                "bandwidth_used": bandwidth_deg,
                "grid_size": grid_size,
                "filter_incident_count": incident_count,
            },
        }, status=status.HTTP_200_OK)
