# /api/urls.py.

from django.urls import path, include
from rest_framework.routers import DefaultRouter
# For nested routes
from rest_framework_nested import routers as nested_routers

from . import views
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView, TokenBlacklistView

# --- Main Router ---
router = DefaultRouter()
router.register(r'incidents', views.IncidentViewSet, basename='incident')
router.register(r'categories', views.CategoryViewSet, basename='category')
router.register(r'comments', views.CommentViewSet, basename='comment') # For direct access /comments/{id}
router.register(r'notifications', views.NotificationViewSet, basename='notification')

# --- Nested Router for Comments under Incidents ---
# /incidents/{incident_pk}/comments/
incidents_router = nested_routers.NestedDefaultRouter(router, r'incidents', lookup='incident')
incidents_router.register(r'comments', views.CommentViewSet, basename='incident-comments')
# This will generate URLs like:
# /incidents/{incident_pk}/comments/ (GET, POST)
# /incidents/{incident_pk}/comments/{pk}/ (GET, PUT, DELETE) - but CommentViewSet handles /comments/{pk} better directly.
# Let's adjust CommentViewSet to handle nested creation cleanly.

urlpatterns = [
    # --- Main API Router ---
    path('', include(router.urls)),
    path('', include(incidents_router.urls)), # Include nested comment routes

    # --- Authentication ---
    path('auth/register/', views.RegisterView.as_view(), name='auth_register'),
    path('auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'), # JWT Login
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),      # JWT Refresh
    path('auth/logout/', TokenBlacklistView.as_view(), name='token_blacklist'),   # Blacklists the refresh token
    # path('auth/password-reset/', include('django_rest_passwordreset.urls', namespace='password_reset')), # If using package
    # TODO: Add custom password reset URLs if implementing manually

    # --- User Management ---
    path('users/me/', views.UserProfileView.as_view(), name='user_profile'),
    # Add the new URL pattern here:
    path('users/<int:pk>/reputation/', views.UserReputationView.as_view(), name='user-reputation'),
    # TODO: Add user avatar upload URL

    # --- Predictive Analytics ---
    path('predict/risk/', views.PredictRiskView.as_view(), name='predict_risk'),
    path('predict/hotspots/', views.PredictHotspotsView.as_view(), name='predict_hotspots'),

    # --- Administration ---
    path('admin/incidents/<int:incident_id>/verify/', views.AdminVerifyIncidentView.as_view(), name='admin_verify_incident'),
    # TODO: Add admin category management URL
    # TODO: Add admin analytics URL

    # --- Nested Routes (Alternative/Manual Setup if Nested Routers are complex) ---
    # Manually define the nested comment list/create if needed, e.g.:
    # path('incidents/<int:incident_pk>/comments/', views.CommentViewSet.as_view({'get': 'list', 'post': 'create'}), name='incident-comment-list'),

]