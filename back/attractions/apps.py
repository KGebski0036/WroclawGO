from django.apps import AppConfig


class AttractionsConfig(AppConfig):
    name = 'attractions'

    def ready(self):
        import attractions.models  # noqa: F401 — ensures signals are connected
