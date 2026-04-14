# Generated migration for SkinColor model updates

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('attractions', '0002_shop_and_visits'),
    ]

    operations = [
        migrations.AddField(
            model_name='skincolor',
            name='image_file_name',
            field=models.CharField(default='default.png', help_text='Filename for the skin preview image', max_length=255),
        ),
        migrations.AddField(
            model_name='skincolor',
            name='is_premium',
            field=models.BooleanField(default=False, help_text='If True, this skin cannot be purchased and is given to all users'),
        ),
    ]
