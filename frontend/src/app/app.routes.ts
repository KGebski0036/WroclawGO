import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { AttractionDetailComponent } from './pages/attraction-detail/attraction-detail.component';
import { AvatarAchievementsComponent } from './pages/avatar-achievements/avatar-achievements.component';
import { AvatarPlaceholderComponent } from './pages/avatar-placeholder/avatar-placeholder.component';
import { AvatarShopComponent } from './pages/avatar-shop/avatar-shop.component';
import { MapViewComponent } from './pages/map-view/map-view.component';
import { LoginComponent } from './pages/login/login.component';
import { RegisterComponent } from './pages/register/register.component';
import { VisitedAttractionsComponent } from './pages/visited-attractions/visited-attractions.component';

export const routes: Routes = [
	{ path: '', redirectTo: 'map', pathMatch: 'full' },
	{ path: 'map', component: MapViewComponent },
	{ path: 'attraction/:id', component: AttractionDetailComponent },
	{ path: 'login', component: LoginComponent },
	{ path: 'register', component: RegisterComponent },
	{
		path: 'your-avatar',
		canActivate: [authGuard],
		children: [
			{ path: '', component: AvatarPlaceholderComponent },
			{ path: 'wardrobe', component: AvatarShopComponent },
			{ path: 'customize', redirectTo: 'wardrobe', pathMatch: 'full' },
			{ path: 'shop', redirectTo: 'wardrobe', pathMatch: 'full' },
			{ path: 'achievements', component: AvatarAchievementsComponent },
			{ path: 'visited', component: VisitedAttractionsComponent },
		]
	},
	{ path: '**', redirectTo: 'map' }
];
