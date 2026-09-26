# /api/serializers.py

from django.contrib.auth.models import User
from django.contrib.gis.geos import Point
from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer # Keep this for other serializers
from .models import Profile, Category, Incident, IncidentMedia, Vote, Comment, Notification

# --- User and Profile Serializers ---

class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = ['avatar_url', 'is_trusted_reporter', 'social_stats', 'preferences']

class UserSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(required=False, read_only=True) # Read-only in user list/detail context

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'is_staff', 'profile']
        read_only_fields = ['id', 'is_staff'] # ID and role should not be changed directly

    # Handle nested profile update/create if profile data is provided
    # Note: This update is typically called from the UserProfileView (PUT /users/me)
    def update(self, instance, validated_data):
        profile_data = validated_data.pop('profile', None)
        # Update User fields
        instance = super().update(instance, validated_data)

        # Update Profile fields if provided
        # Ensure profile exists before attempting update
        profile, created = Profile.objects.get_or_create(user=instance)
        if profile_data:
            profile_serializer = ProfileSerializer(profile, data=profile_data, partial=True)
            if profile_serializer.is_valid(raise_exception=True):
                profile_serializer.save()
        return instance

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})
    password2 = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'}, label="Confirm Password")
    first_name = serializers.CharField(required=False, allow_blank=True, allow_null=True) # Allow null/blank
    last_name = serializers.CharField(required=False, allow_blank=True, allow_null=True) # Allow null/blank

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password2', 'first_name', 'last_name')

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        # Add more validation if needed (e.g., password complexity)
        return attrs

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        # Create Profile along with User
        Profile.objects.get_or_create(user=user) # Use get_or_create just in case
        return user

# --- Category Serializer ---

class CategorySerializer(serializers.ModelSerializer):
    # Optionally show subcategories if needed in responses
    # subcategories = serializers.PrimaryKeyRelatedField(many=True, read_only=True)

    class Meta:
        model = Category
        fields = ['id', 'name', 'parent', 'icon_url', 'risk_level'] #'subcategories']


# --- Incident Serializers ---

# Basic serializer for lists/markers, less detail (remains unchanged)
class IncidentMarkerSerializer(GeoFeatureModelSerializer):
    """ Simplified Incident Serializer for Map Markers """
    category_name = serializers.CharField(source='category.name', read_only=True)
    risk_level = serializers.IntegerField(source='category.risk_level', read_only=True, allow_null=True)
    comments = serializers.SerializerMethodField(read_only=True)
    vote_summary = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Incident
        geo_field = "location" # Field containing geometry
        # Make sure fields match your frontend expectations for markers
        fields = ('id', 'title', 'category', 'category_name', 'risk_level', 'incident_date','description','city_name','comments','vote_summary')
        # Ensure id is included if you rely on feature.id on the frontend
        auto_id = True

    def get_comments(self, obj):
        # Depending on performance needs, serialize comments or just give a count/link
        return CommentSerializer(obj.comments.filter(parent_comment=None), many=True, context=self.context).data
        #return obj.comments.filter(parent_comment=None).data

    def get_vote_summary(self, obj):
        return f"Like(s): {obj.upvotes}, Dislike(s): {obj.downvotes}"


# Detailed serializer for incident details page (remains unchanged)
class IncidentDetailSerializer(GeoFeatureModelSerializer):
    """ Detailed Incident Serializer including related data """
    created_by = UserSerializer(read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    sub_category_name = serializers.CharField(source='sub_category.name', read_only=True, allow_null=True)
    media = serializers.SerializerMethodField(read_only=True)
    comments = serializers.SerializerMethodField(read_only=True) # Or use nested serializers
    current_user_vote = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Incident
        geo_field = "location"
        fields = (
            'id', 'title', 'description', 'location', # location will be GeoJSON geometry
            'category', 'category_name', 'sub_category', 'sub_category_name',
            'incident_date', 'is_verified',
            'created_by', 'created_at', 'updated_at',
            'city_name', 'city_population',
            'upvotes', 'downvotes', 'media', 'comments', 'current_user_vote'
        )
        # Define read_only_fields explicitly for clarity if needed, though many are covered by nested serializers etc.
        read_only_fields = ('created_by', 'created_at', 'updated_at', 'is_verified', 'upvotes', 'downvotes', 'media', 'comments', 'current_user_vote', 'category_name', 'sub_category_name')
        auto_id = True # Include feature ID

    def get_media(self, obj):
        # Consider serializing media properly if you need more than just URLs
        # return IncidentMediaSerializer(obj.media.all(), many=True, context=self.context).data
        return [m.media_url for m in obj.media.all()]

    def get_comments(self, obj):
        # Depending on performance needs, serialize comments or just give a count/link
        # return CommentSerializer(obj.comments.filter(parent_comment=None), many=True, context=self.context).data
        return obj.comments.filter(parent_comment=None).count()

    def get_current_user_vote(self, obj):
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            try:
                vote = Vote.objects.get(incident=obj, user=request.user)
                return vote.vote_type
            except Vote.DoesNotExist:
                return None
        return None

# --- CORRECTED Serializer for creating/updating incidents ---
class IncidentCreateUpdateSerializer(serializers.ModelSerializer):
    # Fields to accept lat/lon input, but not include them in the response
    latitude = serializers.FloatField(write_only=True, required=True)
    longitude = serializers.FloatField(write_only=True, required=True)

    class Meta:
        model = Incident
        fields = (
            'id',  # Include 'id' - it's read-only by default but useful in response
            'title',
            'description',
            'latitude', # Input field
            'longitude',# Input field
            'category',
            'sub_category',
            'incident_date',
            'city_name',
            'city_population',
            'location', # Include the actual model field
            # Fields like 'created_by', 'upvotes', 'downvotes', 'is_verified' are handled by the view/model defaults
        )
        # Mark 'location' as read-only *for input validation only*.
        # It will still be populated by the 'create'/'update' methods.
        read_only_fields = ('location',)

    def create(self, validated_data):
        # Pop lat/lon as they aren't model fields
        latitude = validated_data.pop('latitude')
        longitude = validated_data.pop('longitude')

        # Create the Point object for the actual 'location' model field
        validated_data['location'] = Point(longitude, latitude, srid=4326)

        # Set created_by from the request context (passed by the view)
        # Ensure the view adds 'request' to the serializer context
        request = self.context.get('request', None)
        if request and hasattr(request, 'user'):
            validated_data['created_by'] = request.user
        else:
            # Handle cases where user might not be available (e.g., tests without request context)
            # This might raise an error or require a default user depending on your needs
             raise serializers.ValidationError("User context not available in serializer.")


        # Create the Incident instance using the parent 'create' method
        instance = super().create(validated_data)
        return instance

    def update(self, instance, validated_data):
         # Handle lat/lon update similarly if provided
        latitude = validated_data.pop('latitude', None)
        longitude = validated_data.pop('longitude', None)
        if latitude is not None and longitude is not None:
            instance.location = Point(longitude, latitude, srid=4326)

        # Prevent changing the reporter on update
        validated_data.pop('created_by', None)

        # Update the Incident instance using the parent 'update' method
        instance = super().update(instance, validated_data)
        return instance


# --- Media Serializer (remains unchanged) ---

class IncidentMediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = IncidentMedia
        fields = ['id', 'incident', 'media_url', 'media_type', 'uploaded_at']
        read_only_fields = ['id', 'incident', 'uploaded_at'] # Incident set via URL usually

# --- Vote Serializer (remains unchanged) ---

class VoteCountSerializer(serializers.Serializer):
    upvotes = serializers.IntegerField()
    downvotes = serializers.IntegerField()
    current_user_vote = serializers.ChoiceField(choices=[('up', 'Up'), ('down', 'Down'), (None, 'None')], required=False, allow_null=True)


# --- Comment Serializers (remains unchanged) ---

# Recursive serializer helper
class RecursiveField(serializers.Serializer):
    def to_representation(self, value):
        # Use the same serializer as the parent (CommentSerializer)
        serializer = self.parent.parent.__class__(value, context=self.context)
        return serializer.data

class CommentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    replies = RecursiveField(many=True, read_only=True) # For nested comments

    class Meta:
        model = Comment
        fields = ['id', 'incident', 'user', 'parent_comment', 'content', 'created_at', 'updated_at', 'replies']
        read_only_fields = ['id', 'user', 'created_at', 'updated_at', 'replies', 'incident']
        # parent_comment can be writeable on creation if replying directly via this serializer

class CommentCreateSerializer(serializers.ModelSerializer):
     class Meta:
        model = Comment
        fields = ['content', 'parent_comment'] # incident and user set in view


# --- Notification Serializer (remains unchanged) ---

class NotificationSerializer(serializers.ModelSerializer):
    related_incident_title = serializers.CharField(source='related_incident.title', read_only=True, allow_null=True)

    class Meta:
        model = Notification
        fields = [
            'id', 'user', 'notification_type', 'content',
            'is_read', 'created_at', 'related_incident', 'related_incident_title'
        ]
        read_only_fields = ('id', 'user', 'created_at', 'related_incident', 'related_incident_title', 'notification_type', 'content') # User sets 'is_read' via action