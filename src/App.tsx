import { useEffect } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Dashboard } from './pages/Dashboard';
import { useStore } from './store/useStore';
import { Spheres } from './pages/Spheres';
import { SphereDetails } from './pages/SphereDetails';
import { Tasks } from './pages/Tasks';
import { Habits } from './pages/Habits';
import { Analytics } from './pages/Analytics';
import { Finance } from './pages/Finance';
import { Workouts } from './pages/Workouts';
import { Settings } from './pages/Settings';
import { Passwords } from './pages/Passwords';
import { Household } from './pages/Household';
import { Goals } from './pages/Goals';
import { WorkSchedule } from './pages/WorkSchedule';
import { ShoppingList } from './pages/ShoppingList';
import { ShareTarget } from './pages/ShareTarget';
import { Tools } from './pages/Tools';
import { PinLockScreen } from './components/PinLockScreen';

export default function App() {
  const { checkRegularPayments } = useStore();

  useEffect(() => {
    checkRegularPayments();
  }, [checkRegularPayments]);

  return (
    <BrowserRouter>
      <PinLockScreen />
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="spheres" element={<Spheres />} />
          <Route path="spheres/:id" element={<SphereDetails />} />
          <Route path="tasks" element={<Tasks />} />
          <Route path="habits" element={<Habits />} />
          <Route path="finance" element={<Finance />} />
          <Route path="workouts" element={<Workouts />} />
          <Route path="household" element={<Household />} />
          <Route path="goals" element={<Goals />} />
          <Route path="work-schedule" element={<WorkSchedule />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="shopping-list" element={<ShoppingList />} />
          <Route path="passwords" element={<Passwords />} />
          <Route path="tools" element={<Tools />} />
          <Route path="settings" element={<Settings />} />
          <Route path="share-target" element={<ShareTarget />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
