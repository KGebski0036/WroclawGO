from .models import Achievement, UserAchievement, VisitedAttraction


def _visited_count(user):
    return VisitedAttraction.objects.filter(user=user).count()


def _visited_count_by_category(user, category_name):
    return VisitedAttraction.objects.filter(
        user=user,
        attraction__category__name__iexact=category_name,
    ).count()


def _total_in_category(category_name):
    from .models import Attraction
    return Attraction.objects.filter(category__name__iexact=category_name).count()


# --- Individual achievement checks (return True if requirement is met) ---

def check_first_steps(user):
    return _visited_count(user) >= 1


def check_tourist(user):
    return _visited_count(user) >= 4


def check_explorer(user):
    return _visited_count(user) >= 10


def check_adventurer(user):
    return _visited_count(user) >= 25


def check_traveler(user):
    return _visited_count(user) >= 50


def check_dwarf_hunter(user):
    return _visited_count_by_category(user, 'krasnal') >= 20


def check_dwarf_master(user):
    total = _total_in_category('krasnal')
    if total == 0:
        return False
    return _visited_count_by_category(user, 'krasnal') >= total


def check_museum_enthusiast(user):
    return _visited_count_by_category(user, 'muzeum') >= 3


def check_nature_walker(user):
    return _visited_count_by_category(user, 'park') >= 3


def check_monument_hunter(user):
    return _visited_count_by_category(user, 'zabytki') >= 5


ACHIEVEMENT_CHECKS = {
    'First Steps': check_first_steps,
    'Tourist': check_tourist,
    'Explorer': check_explorer,
    'Adventurer': check_adventurer,
    'Traveler': check_traveler,
    'Dwarf Hunter': check_dwarf_hunter,
    'Dwarf Master': check_dwarf_master,
    'Museum Enthusiast': check_museum_enthusiast,
    'Nature Walker': check_nature_walker,
    'Monument Hunter': check_monument_hunter,
}


def check_achievements(user):
    """
--
    """
    already_earned_ids = set(
        UserAchievement.objects.filter(user=user).values_list('achievement_id', flat=True)
    )
    candidates = Achievement.objects.exclude(id__in=already_earned_ids)

    newly_earned = []
    points_to_add = 0

    for achievement in candidates:
        check_fn = ACHIEVEMENT_CHECKS.get(achievement.name)
        if check_fn and check_fn(user):
            UserAchievement.objects.create(user=user, achievement=achievement)
            points_to_add += achievement.points_reward
            newly_earned.append(achievement)

    if points_to_add > 0:
        user.points += points_to_add
        user.save(update_fields=['points'])

    return newly_earned
