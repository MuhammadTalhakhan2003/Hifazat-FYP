from django.contrib.gis.db import models as gis_models  # For PointField.
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.db import models # Ensure this is imported
from django.db.models import Sum, Count, Q # Import aggregation tools

class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    avatar_url = models.URLField(max_length=500, blank=True, null=True)
    is_trusted_reporter = models.BooleanField(default=False)
    social_stats = models.JSONField(default=dict) # Store upvotes_given, reports_made etc.
    preferences = models.JSONField(default=dict) # Store notification_types, language etc.

    def __str__(self):
        return f"{self.user.username}'s Profile"

    # --- Add this method ---
    def calculate_reputation(self):
        """Calculates the user's reputation score based on their incident reporting."""
        user = self.user # Get the associated user

        # Aggregate data from incidents reported by this user
        incident_stats = Incident.objects.filter(created_by=user).aggregate(
            total_reports=Count('id'),
            verified_reports=Count('id', filter=Q(is_verified=True)),
            total_upvotes=Sum('upvotes'),
            total_downvotes=Sum('downvotes')
        )

        # Handle potential None values from aggregations if user has no incidents
        verified_reports_count = incident_stats.get('verified_reports', 0) or 0
        total_upvotes_count = incident_stats.get('total_upvotes', 0) or 0
        total_downvotes_count = incident_stats.get('total_downvotes', 0) or 0

        # Apply the formula
        reputation = 0
        reputation += verified_reports_count * 10
        reputation += total_upvotes_count * 1
        reputation -= total_downvotes_count * 2 # Note the subtraction

        # Add trusted reporter bonus
        if self.is_trusted_reporter:
            reputation += 50

        # Ensure reputation doesn't go below a certain threshold? (Optional)
        # reputation = max(0, reputation) # Example: Minimum score of 0

        return reputation
    # --- End of added method ---

# Categories Table
class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)  # Ensure category names are unique
    parent = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='subcategories')
    icon_url = models.URLField(max_length=500, blank=True, null=True)
    risk_level = models.IntegerField(choices=[(i, i) for i in range(1, 6)], null=True, blank=True)  # 1 to 5

    class Meta:
        verbose_name_plural = "categories"  # Correct pluralization in admin

    def __str__(self):
        return self.name

# Incidents Table
class Incident(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True, null=True)
    # Use PointField for geographic location (PostGIS will automatically create spatial index)
    location = gis_models.PointField(srid=4326, geography=True)
    category = models.ForeignKey(Category, related_name='incidents_primary', on_delete=models.PROTECT)  # Prevent deleting category if incidents exist
    sub_category = models.ForeignKey(Category, related_name='incidents_secondary', on_delete=models.PROTECT, null=True, blank=True)
    incident_date = models.DateTimeField()
    is_verified = models.BooleanField(default=False)
    created_by = models.ForeignKey(User, related_name='reported_incidents', on_delete=models.CASCADE)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)  # Automatically updated on save
    city_name = models.CharField(max_length=100, blank=True, null=True)
    city_population = models.IntegerField(blank=True, null=True)
    upvotes = models.IntegerField(default=0)
    downvotes = models.IntegerField(default=0)

    class Meta:
        indexes = [
            # PostGIS automatically creates a GiST index for the PointField
            models.Index(fields=['category']),
            models.Index(fields=['incident_date']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"{self.title} ({self.id})"

# Media Table
class IncidentMedia(models.Model):
    MEDIA_TYPE_CHOICES = [
        ('image', 'Image'),
        ('video', 'Video'),
    ]
    incident = models.ForeignKey(Incident, related_name='media', on_delete=models.CASCADE)
    media_url = models.URLField(max_length=500)  # Assuming URLs for now
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPE_CHOICES)
    uploaded_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Media for Incident {self.incident_id} ({self.media_type})"

# Votes Table
class Vote(models.Model):
    VOTE_TYPE_CHOICES = [
        ('up', 'Upvote'),
        ('down', 'Downvote'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    incident = models.ForeignKey(Incident, related_name='votes', on_delete=models.CASCADE)
    vote_type = models.CharField(max_length=4, choices=VOTE_TYPE_CHOICES)
    voted_at = models.DateTimeField(default=timezone.now)

    class Meta:
        # Ensure a user can only vote once per incident
        unique_together = ('user', 'incident')
        indexes = [
            models.Index(fields=['user', 'incident']),
        ]

    def __str__(self):
        return f"{self.user.username} voted {self.vote_type} on Incident {self.incident_id}"

# Comments Table
class Comment(models.Model):
    incident = models.ForeignKey(Incident, related_name='comments', on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name='comments', on_delete=models.CASCADE)
    parent_comment = models.ForeignKey('self', null=True, blank=True, related_name='replies', on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['incident', 'created_at']),
        ]
        ordering = ['created_at']  # Default order

    def __str__(self):
        return f"Comment by {self.user.username} on Incident {self.incident_id}"

# Notifications Table
class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('new_incident', 'New Incident in Area'),
        ('incident_update', 'Incident Updated'),
        ('new_comment', 'New Comment on Report'),
        ('comment_reply', 'New Reply to Comment'),
        ('verification', 'Incident Verified'),
        ('mention', 'User Mention'),
    ]
    user = models.ForeignKey(User, related_name='notifications', on_delete=models.CASCADE)
    notification_type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES)
    content = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    related_incident = models.ForeignKey(Incident, null=True, blank=True, on_delete=models.CASCADE)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'is_read', 'created_at']),
        ]
        ordering = ['-created_at']  # Show newest first

    def __str__(self):
        return f"Notification for {self.user.username}: {self.notification_type}"

# Password Reset Codes Table
class PasswordResetCode(models.Model):
    """A short-lived 6-digit code emailed to a user who forgot their password.
    Only a hash of the code is stored, never the code itself."""
    user = models.ForeignKey(User, related_name='password_reset_codes', on_delete=models.CASCADE)
    code_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)  # Wrong guesses so far
    is_used = models.BooleanField(default=False)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"Password reset code for {self.user.username} ({self.created_at:%Y-%m-%d %H:%M})"
