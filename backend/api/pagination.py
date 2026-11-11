from rest_framework.pagination import PageNumberPagination


class IncidentPagination(PageNumberPagination):
    """Small pages for the (large) incidents table; clients may ask for up to 200 via ?page_size=."""
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 200
