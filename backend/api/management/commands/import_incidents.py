# /api/management/commands/import_incidents.py

import csv
from datetime import datetime
from django.core.management.base import BaseCommand, CommandError
from django.contrib.gis.geos import Point
from django.contrib.auth.models import User
from django.utils import timezone  # Import timezone
from api.models import Incident, Category  # Import your models

# Define the expected date format in your CSV
# Adjust this if your 'Date' column format is different
CSV_DATE_FORMAT = '%Y-%m-%d'

class Command(BaseCommand):
    help = 'Imports incident data from a specified CSV file.'

    def add_arguments(self, parser):
        # Define a mandatory argument for the CSV file path
        parser.add_argument('csv_file', type=str, help='The path to the CSV file to import.')
        # Optional: Argument for the username of the user to assign incidents to
        parser.add_argument(
            '--user',
            type=str,
            help='Username of the user to assign the imported incidents to (defaults to the first superuser).',
            default=None
        )

    def handle(self, *args, **options):
        csv_file_path = options['csv_file']
        username_assign = options['user']

        # --- Get the User to Assign Incidents To ---
        assign_user = None
        if username_assign:
            try:
                assign_user = User.objects.get(username=username_assign)
                self.stdout.write(self.style.SUCCESS(f"Assigning incidents to user: {username_assign}"))
            except User.DoesNotExist:
                raise CommandError(f"User '{username_assign}' does not exist.")
        else:
            # Default to the first superuser found
            assign_user = User.objects.filter(is_superuser=True).order_by('id').first()
            if not assign_user:
                 raise CommandError("No superuser found to assign incidents to. Please create one or specify a user with --user.")
            self.stdout.write(self.style.WARNING(f"No user specified. Assigning incidents to first superuser: {assign_user.username}"))


        # --- Start Processing the CSV ---
        self.stdout.write(f"Starting import from {csv_file_path}...")
        import_count = 0
        error_count = 0

        try:
            with open(csv_file_path, mode='r', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile) # Use DictReader for easy column access

                if not reader.fieldnames:
                     raise CommandError(f"CSV file {csv_file_path} appears to be empty or header is missing.")

                # Basic check for required columns (adjust as needed)
                required_cols = ['Title', 'Date', 'First Paragraph', 'City', 'Latitude', 'Longitude', 'Crime Category']
                if not all(col in reader.fieldnames for col in required_cols):
                     raise CommandError(f"CSV file missing one or more required columns: {required_cols}")

                for i, row in enumerate(reader):
                    try:
                        # --- 1. Extract and Clean Data ---
                        title = row.get('Title', '').strip()
                        date_str = row.get('Date', '').strip()
                        description = row.get('First Paragraph', '').strip()
                        city = row.get('City', '').strip()
                        latitude_str = row.get('Latitude', '').strip()
                        longitude_str = row.get('Longitude', '').strip()
                        category_name = row.get('Crime Category', '').strip()
                        sub_category_name = row.get('Sub Category', '').strip() # Optional
                        location_desc = row.get('Location', '').strip() # Optional, currently not in model
                        city_pop_str = row.get('City Population', '').strip() # Optional

                        # Basic validation
                        if not all([title, date_str, city, latitude_str, longitude_str, category_name]):
                            self.stderr.write(self.style.WARNING(f"Skipping row {i+2}: Missing required data (Title, Date, Lat, Lon, Category)."))
                            error_count += 1
                            continue

                        # --- 2. Transform Data ---
                        # Parse Date - Make timezone aware (assuming UTC if not specified)
                        try:
                            incident_dt_naive = datetime.strptime(date_str, CSV_DATE_FORMAT)
                            # Make the datetime object timezone-aware using the project's default timezone
                            incident_dt_aware = timezone.make_aware(incident_dt_naive, timezone.get_default_timezone())
                        except ValueError:
                            self.stderr.write(self.style.WARNING(f"Skipping row {i+2}: Invalid date format '{date_str}'. Expected '{CSV_DATE_FORMAT}'."))
                            error_count += 1
                            continue

                        # Parse Lat/Lon and Create Point
                        try:
                            latitude = float(latitude_str)
                            longitude = float(longitude_str)
                            # IMPORTANT: Point uses (longitude, latitude) order! SRID 4326 is standard GPS.
                            location_point = Point(longitude, latitude, srid=4326)
                        except (ValueError, TypeError):
                            self.stderr.write(self.style.WARNING(f"Skipping row {i+2}: Invalid latitude/longitude values '{latitude_str}', '{longitude_str}'."))
                            error_count += 1
                            continue

                        # Parse City Population
                        city_population = None
                        if city_pop_str:
                            try:
                                city_population = int(city_pop_str)
                            except ValueError:
                                self.stderr.write(self.style.WARNING(f"Row {i+2}: Invalid city population value '{city_pop_str}'. Setting to null."))
                                # Don't skip the row, just leave population as null

                        # --- 3. Handle Categories (Get or Create) ---
                        # Main Category
                        category_obj, created = Category.objects.get_or_create(
                            name=category_name,
                            defaults={'parent': None} # Assume top-level if created here
                        )
                        if created:
                            self.stdout.write(self.style.NOTICE(f"Created new category: '{category_name}'"))

                        # Sub Category (if provided)
                        sub_category_obj = None
                        if sub_category_name:
                            sub_category_obj, created = Category.objects.get_or_create(
                                name=sub_category_name,
                                defaults={'parent': category_obj} # Set parent relationship
                            )
                            # Ensure existing sub-category has the correct parent
                            if not created and sub_category_obj.parent != category_obj:
                                self.stdout.write(self.style.WARNING(f"Warning Row {i+2}: Subcategory '{sub_category_name}' exists but under a different parent. Associating with '{category_name}' for this incident."))
                                # Don't change the parent globally here, just use the object ID for the incident
                            elif created:
                                self.stdout.write(self.style.NOTICE(f"Created new sub-category: '{sub_category_name}' under '{category_name}'"))


                        # --- 4. Create Incident ---
                        # Use update_or_create to prevent duplicates based on title/date/location?
                        # Or just create - assuming CSV rows are unique events for now.
                        incident = Incident(
                            title=title,
                            description=description,
                            location=location_point,
                            category=category_obj,
                            sub_category=sub_category_obj, # Will be None if not found/provided
                            incident_date=incident_dt_aware,
                            created_by=assign_user,
                            city_name=city,
                            city_population=city_population,
                            is_verified=False # Assume imported incidents are not verified initially
                            # Add other fields with defaults if necessary
                        )
                        incident.save()
                        import_count += 1

                        # Provide progress feedback
                        if import_count % 100 == 0:
                            self.stdout.write(f"Imported {import_count} incidents...")

                    except Exception as e:
                        self.stderr.write(self.style.ERROR(f"Error processing row {i+2}: {e}"))
                        self.stderr.write(f"  Row data: {row}") # Print row data on error
                        error_count += 1
                        # Continue to the next row

        except FileNotFoundError:
            raise CommandError(f"CSV file not found at path: {csv_file_path}")
        except Exception as e:
            # Catch broader errors during file opening or initial checks
            raise CommandError(f"An unexpected error occurred: {e}")

        # --- Final Report ---
        if error_count > 0:
             self.stdout.write(self.style.WARNING(f"Import complete. Imported {import_count} incidents with {error_count} errors/skipped rows."))
        else:
             self.stdout.write(self.style.SUCCESS(f"Successfully imported {import_count} incidents."))