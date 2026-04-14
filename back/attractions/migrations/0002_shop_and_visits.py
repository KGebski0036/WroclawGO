import django.contrib.gis.db.models.fields
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('attractions', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='SkinColor',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('color_value', models.CharField(max_length=7)),
                ('price', models.PositiveIntegerField(default=50)),
            ],
            options={
                'verbose_name': 'Skin Color',
                'verbose_name_plural': 'Skin Colors',
            },
        ),
        migrations.CreateModel(
            name='VisitedAttraction',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('visited_at', models.DateTimeField(auto_now_add=True)),
                ('attraction', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='visits', to='attractions.attraction')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='visited_attractions', to='attractions.user')),
            ],
            options={
                'ordering': ['-visited_at'],
            },
        ),
        migrations.AddField(
            model_name='user',
            name='selected_skin',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='selected_by', to='attractions.skincolor'),
        ),
        migrations.AddField(
            model_name='user',
            name='owned_skins',
            field=models.ManyToManyField(blank=True, related_name='owners', to='attractions.skincolor'),
        ),
    ]
