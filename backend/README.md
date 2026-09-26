# Hifazat Backend - Community-Driven Safety Awareness Application

## 1. Project Overview

Hifazat is a mobile and web application designed to enhance community safety through user-reported data on safety incidents. It leverages real-time information sharing, geolocation, data visualization, and potentially AI-driven predictions to empower users and inform stakeholders.

This repository contains the backend API service built with:

*   **Framework:** Django
*   **API:** Django REST Framework (DRF)
*   **Database:** PostgreSQL with PostGIS extension for geospatial capabilities
*   **Authentication:** JWT (via djangorestframework-simplejwt)
*   **Real-time (Optional):** Django Channels (setup included, WebSocket implementation pending)
*   **Environment:** Developed and tested primarily on WSL (Windows Subsystem for Linux) with Ubuntu.

## 2. Prerequisites

Before you begin, ensure you have the following installed on your **WSL (Ubuntu)** environment:

*   **WSL 2:** Recommended for better performance.
*   **Ubuntu:** A recent LTS version (e.g., 20.04, 22.04) running within WSL.
*   **Git:** For cloning the repository. (`sudo apt update && sudo apt install git`)
*   **Python 3 & Pip:** A recent version (e.g., 3.8+). (`sudo apt update && sudo apt install python3 python3-pip python3-venv`)
*   **PostgreSQL Client Libraries:** Needed for `psycopg2`. (`sudo apt install libpq-dev`)
*   **PostgreSQL Server & PostGIS:**
    *   PostgreSQL server (e.g., version 14, 15, 16).
    *   PostGIS extension compatible with your PostgreSQL version.
    *   `postgresql-contrib` package.
*   **Redis Server (Optional but recommended for Channels):** (`sudo apt install redis-server`)

## 3. Database Setup (PostgreSQL + PostGIS)

This is a critical step. Follow these instructions carefully within your WSL terminal:

1.  **Install PostgreSQL & PostGIS:**
    ```bash
    sudo apt update
    # Adjust version numbers if needed (e.g., use 15 or 16 if installed)
    sudo apt install -y postgresql postgresql-contrib postgresql-14-postgis-3 postgresql-14-postgis-3-scripts libpq-dev
    # Verify your installed version using: psql --version
    ```

2.  **Start & Enable PostgreSQL Service:**
    ```bash
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    sudo systemctl status postgresql # Verify it's active (running)
    ```

3.  **Access PostgreSQL Prompt as Superuser:**
    ```bash
    sudo -u postgres psql
    ```

4.  **Create Database & User (inside psql):**
    ```sql
    -- Create the application database
    CREATE DATABASE hifazat_db;

    -- Create a dedicated user for the application (replace 'your_strong_password_here'!)
    CREATE USER hifazat_user WITH PASSWORD 'your_strong_password_here';

    -- Grant basic connection/database privileges
    GRANT ALL PRIVILEGES ON DATABASE hifazat_db TO hifazat_user;

    -- Connect to the newly created database TO ENABLE EXTENSION AND SET PERMISSIONS
    \c hifazat_db

    -- *** IMPORTANT: Enable the PostGIS extension *within* the database ***
    CREATE EXTENSION postgis;

    -- Grant necessary schema privileges to the application user
    -- This allows the user to create tables (like django_migrations) in the public schema
    GRANT USAGE, CREATE ON SCHEMA public TO hifazat_user;

    -- Grant default privileges for future objects created by this user or migrations
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO hifazat_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO hifazat_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO hifazat_user; -- Might be needed depending on PostGIS usage

    -- (Optional but recommended) Change Database Owner
    -- ALTER DATABASE hifazat_db OWNER TO hifazat_user;

    -- Verify PostGIS is enabled (Optional)
    SELECT PostGIS_Version();

    -- Exit psql prompt
    \q
    ```

## 4. Backend Project Setup

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url> hifazat-backend
    cd hifazat-backend
    ```

2.  **Create and Activate Virtual Environment:**
    ```bash
    python3 -m venv venv-hifazat
    source venv-hifazat/bin/activate
    # Your terminal prompt should now start with (venv-hifazat)
    ```

3.  **Upgrade Pip:**
    ```bash
    pip install --upgrade pip
    ```

4.  **Install Dependencies:**
    *(Ensure you have a `requirements.txt` file. If not, create one from the activated virtual environment after installing manually using `pip freeze > requirements.txt`)*
    ```bash
    pip install -r requirements.txt
    # If requirements.txt doesn't exist, you'll need to install manually:
    # pip install django djangorestframework psycopg2-binary djangorestframework-gis channels channels-redis djangorestframework-simplejwt Pillow django-cors-headers django-filter python-dotenv drf-nested-routers
    ```

5.  **Create Environment File (`.env`):**
    Create a file named `.env` in the project root directory (`hifazat-backend/`). Copy the structure from `.env.example` (if provided) or create it with the following content, **replacing placeholder values with your actual settings**:

    ```dotenv
    # .env file

    # Django settings
    DJANGO_SECRET_KEY='your-strong-random-secret-key-here!' # Change this!
    DJANGO_DEBUG=True # True for development, False for production

    # Database settings (Match the user/password created above)
    DB_NAME=hifazat_db
    DB_USER=hifazat_user
    DB_PASSWORD='your_strong_password_here' # The password you set in psql
    DB_HOST=localhost # Or '127.0.0.1'
    DB_PORT=5432

    # Redis settings (If using Channels)
    REDIS_HOST=127.0.0.1
    REDIS_PORT=6379
    ```
    **IMPORTANT:** Add `.env` to your `.gitignore` file to prevent committing secrets!

6.  **Apply Database Migrations:**
    This creates the necessary tables in your `hifazat_db` based on the Django models.
    ```bash
    python manage.py makemigrations api
    python manage.py migrate
    ```
    If you encounter permission errors here, double-check the PostgreSQL setup in Step 3, especially the `GRANT USAGE, CREATE ON SCHEMA public...` commands.

7.  **Create Superuser:**
    This creates an admin account to access the Django Admin interface.
    ```bash
    python manage.py createsuperuser
    ```
    Follow the prompts to set a username, email (optional), and password.

8.  **(Optional) Import Initial Data:**
    If you have incident data in a CSV file matching the expected format (`Page,Title,Date,First Paragraph,City,Latitude,Longitude,Crime Category,Sub Category,Location,City Population`), you can use the management command:
    ```bash
    python manage.py import_incidents path/to/your/data.csv --user <your_superuser_username>
    # Example: python manage.py import_incidents ../data/hifazat_incidents.csv --user admin
    ```
    *(See `api/management/commands/import_incidents.py` for details on required columns and date format).*

## 5. Running the Development Server

1.  **Activate Virtual Environment (if not already active):**
    ```bash
    source venv-hifazat/bin/activate
    ```

2.  **Start the Django Development Server:**
    ```bash
    python manage.py runserver
    ```
    *(This uses Django's built-in server with ASGI support enabled via `config/asgi.py`)*

3.  **Access the Application:**
    *   **API:** The API endpoints are available under `http://127.0.0.1:8000/api/`. You can explore them using tools like Postman, Insomnia, or the DRF Browsable API in your web browser.
    *   **Admin Interface:** Access the Django admin panel at `http://127.0.0.1:8000/admin/` and log in using the superuser credentials created earlier.

## 6. Key Dependencies (via `requirements.txt`)

This project relies on several key Python packages:

*   `django`: Web framework.
*   `djangorestframework`: Toolkit for building Web APIs.
*   `psycopg2-binary`: PostgreSQL adapter for Python.
*   `django-filter`: Filtering support for DRF.
*   `djangorestframework-gis`: GeoDjango support for DRF.
*   `djangorestframework-simplejwt`: JWT authentication for DRF.
*   `channels`: Enables WebSocket/ASGI support.
*   `channels-redis`: Redis backend for Channels layers.
*   `django-cors-headers`: Handles Cross-Origin Resource Sharing headers.
*   `python-dotenv`: Loads environment variables from `.env` file.
*   `drf-nested-routers`: For creating nested API routes (e.g., comments under incidents).
*   `Pillow`: For image processing (if image uploads are implemented).

## 7. API Endpoints

All endpoints are accessed under the `/api/` prefix (e.g., `http://127.0.0.1:8000/api/auth/login/`). Authentication is required for most non-GET endpoints (using JWT Bearer tokens).

### 7.1. Authentication (`/auth/`)

*   `POST /auth/register/` - User registration.
*   `POST /auth/login/` - Obtain JWT access and refresh tokens.
*   `POST /auth/refresh/` - Refresh JWT access token using a valid refresh token.
*   `POST /auth/password-reset/` - Initiate password reset (Requires implementation, e.g., using `django-rest-passwordreset` or custom).
*   `POST /auth/password-reset/confirm/` - Confirm password reset using token (Requires implementation).

### 7.2. User Management (`/users/`)

*   `GET /users/me/` - Get current authenticated user's profile details.
*   `PUT /users/me/` - Replace current user's profile details (Requires all fields).
*   `PATCH /users/me/` - Partially update current user's profile details (e.g., `first_name`, `last_name`).
*   `POST /users/me/avatar/` - Upload profile picture (Requires implementation).
*   `GET /users/{user_pk}/reputation/` - Get a specific user's calculated reputation score.

### 7.3. Categories (`/categories/`)

*   `GET /categories/` - List top-level categories (supports `?search=` parameter).
*   `GET /categories/{category_pk}/` - Retrieve details of a specific category.
*   `GET /categories/{category_pk}/subcategories/` - List subcategories of a specific category.
*   *(Admin)* Management via `/admin/` or dedicated admin API endpoints (requires implementation).

### 7.4. Incidents (`/incidents/`)

*   `POST /incidents/` - Create a new incident report (Requires auth). Body includes `title`, `latitude`, `longitude`, `category`, `incident_date`, etc.
*   `GET /incidents/` - List incidents (GeoJSON FeatureCollection). Supports filtering and searching:
    *   `?page_size={number}` (e.g., `?page_size=100`)
    *   `?page={number}`
    *   `?category={id}` or `?category__in={id1},{id2}` 
    *   `?sub_category={id}`
    *   `?incident_date__gte={YYYY-MM-DD}`
    *   `?incident_date__lte={YYYY-MM-DD}`
    *   `?city_name={name}` or `?city_name__icontains={partial}`
    *   `?is_verified={true|false}`
    *   `?search={term}` (searches title, description, city, category name)
    *   `?ordering={field}` (e.g., `incident_date`, `-upvotes`)
    *   `?in_bbox={min_lon},{min_lat},{max_lon},{max_lat}` (Geographic bounding box filter)
*   `GET /incidents/{incident_pk}/` - Get detailed information for a specific incident (GeoJSON Feature).
*   `PUT /incidents/{incident_pk}/` - Replace incident details (Owner/Admin only).
*   `PATCH /incidents/{incident_pk}/` - Partially update incident details (Owner/Admin only).
*   `DELETE /incidents/{incident_pk}/` - Delete an incident (Owner/Admin only).
*   `POST /incidents/{incident_pk}/media/` - Add media (image/video) to an incident (Requires implementation).
*   `DELETE /incidents/{incident_pk}/media/{media_id}/` - Remove media from an incident (Requires implementation).

### 7.5. Voting (Actions on Incidents)

*   `POST /incidents/{incident_pk}/upvote/` - Upvote an incident (Requires auth).
*   `POST /incidents/{incident_pk}/downvote/` - Downvote an incident (Requires auth).
*   `GET /incidents/{incident_pk}/votes/` - Get vote counts (`upvotes`, `downvotes`) and current user's vote status (`current_user_vote`) for an incident.

### 7.6. Comments & Discussions

*   `POST /incidents/{incident_pk}/comments/` - Add a top-level comment to a specific incident (Requires auth). Uses nested route.
*   `GET /incidents/{incident_pk}/comments/` - List comments for a specific incident. Uses nested route. Supports pagination.
*   `PUT /comments/{comment_pk}/` - Edit a comment (Owner/Admin only).
*   `PATCH /comments/{comment_pk}/` - Partially update a comment (Owner/Admin only).
*   `DELETE /comments/{comment_pk}/` - Delete a comment (Owner/Admin only).
*   `POST /comments/{comment_pk}/reply/` - Reply to an existing comment (Requires auth).
*   `POST /comments/{comment_pk}/report/` - Report an abusive comment (Requires auth, further implementation needed).

### 7.7. Predictive Analytics (`/predict/`) (Placeholders)

*   `GET /predict/risk/` - Get predicted risk level for a location (`?lat=...&lon=...`). (Requires ML model integration).
*   `GET /predict/hotspots/` - Get predicted crime hotspots for an area (`?bbox=...`). (Requires analysis/ML model integration).

### 7.8. Notifications (`/notifications/`)

*   `GET /notifications/` - Get current authenticated user's notifications (Paginated).
*   `PUT /notifications/{notification_pk}/read/` - Mark a specific notification as read (Requires auth).
*   `DELETE /notifications/{notification_pk}/` - Delete a notification (Requires implementation).

### 7.9. Administration (`/admin/`)

*   Access via `http://127.0.0.1:8000/admin/` (Django Admin Interface).
*   `POST /api/admin/incidents/{incident_id}/verify/` - Mark an incident as verified (Admin only API endpoint).
*   *(Future)* Dedicated API endpoints for category management, system analytics, user management, etc.

## 8. Configuration

*   Most configuration is handled in `config/settings.py`.
*   Sensitive settings (Secret Key, Database Credentials, Debug status) should be set using environment variables defined in the `.env` file.
*   CORS settings (`CORS_ALLOWED_ORIGINS`, `CORS_ALLOW_ALL_ORIGINS`) in `settings.py` control which frontend origins can access the API.
*   Database, Cache, and Channel Layer settings are also managed in `settings.py`.
