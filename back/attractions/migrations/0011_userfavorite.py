from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('attractions', '0010_seed_achievements'),
    ]

    operations = [
        migrations.CreateModel(
            name='UserFavorite',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('favorite_user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='favorited_by_relationships', to='attractions.user')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='favorite_relationships', to='attractions.user')),
            ],
            options={
                'unique_together': {('user', 'favorite_user')},
            },
        ),
        migrations.AddConstraint(
            model_name='userfavorite',
            constraint=models.CheckConstraint(condition=models.Q(('favorite_user', models.F('user')), _negated=True), name='prevent_self_favorite'),
        ),
    ]
