import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function NavBar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <nav className="navbar">
      <Link to="/" className="navbar-brand">
        🌍 Travel Logs
      </Link>
      <div className="navbar-links">
        {user ? (
          <>
            <Link to="/places/new" className="btn btn-primary btn-sm">
              + Add place
            </Link>
            <span className="navbar-user">{user.username}</span>
            <button onClick={handleLogout} className="btn btn-outline btn-sm">
              Log out
            </button>
          </>
        ) : (
          <>
            <Link to="/login" className="btn btn-outline btn-sm">
              Log in
            </Link>
            <Link to="/register" className="btn btn-primary btn-sm">
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}
