import { BrowserRouter, Route, Routes } from "react-router-dom";
import NavBar from "./components/NavBar";
import ProtectedRoute from "./components/ProtectedRoute";
import { AuthProvider } from "./context/AuthContext";
import AddPlacePage from "./pages/AddPlacePage";
import DashboardPage from "./pages/DashboardPage";
import EditPlacePage from "./pages/EditPlacePage";
import LoginPage from "./pages/LoginPage";
import PlaceDetailsPage from "./pages/PlaceDetailsPage";
import RegisterPage from "./pages/RegisterPage";

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <NavBar />
        <main className="container">
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />
            <Route element={<ProtectedRoute />}>
              <Route path="/" element={<DashboardPage />} />
              <Route path="/places/new" element={<AddPlacePage />} />
              <Route path="/places/:placeId" element={<PlaceDetailsPage />} />
              <Route path="/places/:placeId/edit" element={<EditPlacePage />} />
            </Route>
            <Route path="*" element={<div className="page-message">Page not found</div>} />
          </Routes>
        </main>
      </BrowserRouter>
    </AuthProvider>
  );
}
