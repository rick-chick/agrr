import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { HomeComponent } from './components/home/home.component';
import { LoginComponent } from './components/auth/login/login.component';

export const routes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'auth/login', redirectTo: 'login', pathMatch: 'full' },
  { path: 'dashboard', component: HomeComponent, canActivate: [authGuard] },
  
  // Masters
  { 
    path: 'farms', 
    loadComponent: () => import('./components/masters/farms/farm-list.component').then(m => m.FarmListComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'farms/new', 
    loadComponent: () => import('./components/masters/farms/farm-create.component').then(m => m.FarmCreateComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'farms/:id/edit', 
    loadComponent: () => import('./components/masters/farms/farm-edit.component').then(m => m.FarmEditComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'farms/:id', 
    loadComponent: () => import('./components/masters/farms/farm-detail.component').then(m => m.FarmDetailComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'crops', 
    loadComponent: () => import('./components/masters/crops/crop-list.component').then(m => m.CropListComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'crops/new', 
    loadComponent: () => import('./components/masters/crops/crop-create.component').then(m => m.CropCreateComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'crops/:id/edit', 
    loadComponent: () => import('./components/masters/crops/crop-edit.component').then(m => m.CropEditComponent),
    canActivate: [authGuard] 
  },
  {
    path: 'crops/:id',
    loadComponent: () => import('./components/masters/crops/crop-detail.component').then(m => m.CropDetailComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pests',
    loadComponent: () => import('./components/masters/pests/pest-list.component').then(m => m.PestListComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pests/new',
    loadComponent: () => import('./components/masters/pests/pest-create.component').then(m => m.PestCreateComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pests/:id/edit',
    loadComponent: () => import('./components/masters/pests/pest-edit.component').then(m => m.PestEditComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pests/:id',
    loadComponent: () => import('./components/masters/pests/pest-detail.component').then(m => m.PestDetailComponent),
    canActivate: [authGuard]
  },
  {
    path: 'fertilizes', 
    loadComponent: () => import('./components/masters/fertilizes/fertilize-list.component').then(m => m.FertilizeListComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'fertilizes/new', 
    loadComponent: () => import('./components/masters/fertilizes/fertilize-create.component').then(m => m.FertilizeCreateComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'fertilizes/:id/edit', 
    loadComponent: () => import('./components/masters/fertilizes/fertilize-edit.component').then(m => m.FertilizeEditComponent),
    canActivate: [authGuard] 
  },
  {
    path: 'fertilizes/:id',
    loadComponent: () => import('./components/masters/fertilizes/fertilize-detail.component').then(m => m.FertilizeDetailComponent),
    canActivate: [authGuard]
  },
  { 
    path: 'pests', 
    loadComponent: () => import('./components/masters/pests/pest-list.component').then(m => m.PestListComponent),
    canActivate: [authGuard] 
  },
  {
    path: 'pesticides',
    loadComponent: () => import('./components/masters/pesticides/pesticide-list.component').then(m => m.PesticideListComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pesticides/new',
    loadComponent: () => import('./components/masters/pesticides/pesticide-create.component').then(m => m.PesticideCreateComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pesticides/:id/edit',
    loadComponent: () => import('./components/masters/pesticides/pesticide-edit.component').then(m => m.PesticideEditComponent),
    canActivate: [authGuard]
  },
  {
    path: 'pesticides/:id',
    loadComponent: () => import('./components/masters/pesticides/pesticide-detail.component').then(m => m.PesticideDetailComponent),
    canActivate: [authGuard]
  },
  {
    path: 'agricultural_tasks',
    loadComponent: () => import('./components/masters/agricultural-tasks/agricultural-task-list.component').then(m => m.AgriculturalTaskListComponent),
    canActivate: [authGuard]
  },
  {
    path: 'agricultural_tasks/new',
    loadComponent: () => import('./components/masters/agricultural-tasks/agricultural-task-create.component').then(m => m.AgriculturalTaskCreateComponent),
    canActivate: [authGuard]
  },
  {
    path: 'agricultural_tasks/:id/edit',
    loadComponent: () => import('./components/masters/agricultural-tasks/agricultural-task-edit.component').then(m => m.AgriculturalTaskEditComponent),
    canActivate: [authGuard]
  },
  {
    path: 'agricultural_tasks/:id',
    loadComponent: () => import('./components/masters/agricultural-tasks/agricultural-task-detail.component').then(m => m.AgriculturalTaskDetailComponent),
    canActivate: [authGuard]
  },
  {
    path: 'interaction_rules',
    loadComponent: () => import('./components/masters/interaction-rules/interaction-rule-list.component').then(m => m.InteractionRuleListComponent),
    canActivate: [authGuard]
  },
  {
    path: 'interaction_rules/new',
    loadComponent: () => import('./components/masters/interaction-rules/interaction-rule-create.component').then(m => m.InteractionRuleCreateComponent),
    canActivate: [authGuard]
  },
  {
    path: 'interaction_rules/:id/edit',
    loadComponent: () => import('./components/masters/interaction-rules/interaction-rule-edit.component').then(m => m.InteractionRuleEditComponent),
    canActivate: [authGuard]
  },
  {
    path: 'interaction_rules/:id',
    loadComponent: () => import('./components/masters/interaction-rules/interaction-rule-detail.component').then(m => m.InteractionRuleDetailComponent),
    canActivate: [authGuard]
  },
  
  // Settings
  { 
    path: 'api-keys', 
    loadComponent: () => import('./components/settings/api-key/api-key.component').then(m => m.ApiKeyComponent),
    canActivate: [authGuard] 
  },
  
  // Plans
  { 
    path: 'plans', 
    loadComponent: () => import('./components/plans/plan-list.component').then(m => m.PlanListComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'plans/:id', 
    loadComponent: () => import('./components/plans/plan-detail.component').then(m => m.PlanDetailComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'plans/:id/optimizing', 
    loadComponent: () => import('./components/plans/plan-optimizing.component').then(m => m.PlanOptimizingComponent),
    canActivate: [authGuard] 
  },
  { 
    path: 'plans/:id/task_schedule', 
    loadComponent: () => import('./components/plans/plan-task-schedule.component').then(m => m.PlanTaskScheduleComponent),
    canActivate: [authGuard] 
  },
  
  // Public Plans
  { 
    path: 'public-plans/new', 
    loadComponent: () => import('./components/public-plans/public-plan-create.component').then(m => m.PublicPlanCreateComponent)
  },
  { 
    path: 'public-plans/select-crop', 
    loadComponent: () => import('./components/public-plans/public-plan-select-crop.component').then(m => m.PublicPlanSelectCropComponent)
  },
  { 
    path: 'public-plans/optimizing', 
    loadComponent: () => import('./components/public-plans/public-plan-optimizing.component').then(m => m.PublicPlanOptimizingComponent)
  },
  { 
    path: 'public-plans/results', 
    loadComponent: () => import('./components/public-plans/public-plan-results.component').then(m => m.PublicPlanResultsComponent)
  },
  
  // Weather
  { 
    path: 'weather', 
    loadComponent: () => import('./components/weather/weather-page.component').then(m => m.WeatherPageComponent),
    canActivate: [authGuard] 
  },
  
  // Static Pages
  { 
    path: 'about', 
    loadComponent: () => import('./components/pages/about/about.component').then(m => m.AboutComponent) 
  },
  { 
    path: 'contact', 
    loadComponent: () => import('./components/pages/contact/contact.component').then(m => m.ContactComponent) 
  },
  { 
    path: 'privacy', 
    loadComponent: () => import('./components/pages/privacy/privacy.component').then(m => m.PrivacyComponent) 
  },
  { 
    path: 'terms', 
    loadComponent: () => import('./components/pages/terms/terms.component').then(m => m.TermsComponent) 
  }
];
