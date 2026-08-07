import { useEffect, useMemo, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  BarChart3,
  Bell,
  CalendarDays,
  LayoutDashboard,
  LogOut,
  Menu,
  Moon,
  Search,
  Sun,
  User,
  Users,
  UserRound,
  X,
  PanelLeftClose,
  PanelLeftOpen,
} from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { useTheme } from "../theme/ThemeContext";
import { getDashboard } from "../api/adminApi";
import { BrandMark, Badge, Button } from "./ui";

const NAV = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/users", label: "Users", icon: Users },
  { to: "/coaches", label: "Coaches", icon: UserRound },
  { to: "/appointments", label: "Appointments", icon: CalendarDays },
  { to: "/insights", label: "Insights", icon: BarChart3 },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const { isDark, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [pendingApps, setPendingApps] = useState(0);
  const [search, setSearch] = useState("");

  useEffect(() => {
    getDashboard()
      .then((dashboard) => {
        setPendingApps(dashboard?.pendingCoachApplications || 0);
      })
      .catch(() => {
        setPendingApps(0);
      });
  }, [location.pathname]);

  useEffect(() => {
    setMobileOpen(false);
    setProfileOpen(false);
    setNotifOpen(false);
  }, [location.pathname]);

  const pageTitle = useMemo(() => {
    const hit = NAV.find((n) =>
      n.end ? location.pathname === n.to : location.pathname.startsWith(n.to),
    );
    return hit?.label || "Dashboard";
  }, [location.pathname]);

  function onSearchSubmit(e) {
    e.preventDefault();
    const q = search.trim().toLowerCase();
    if (!q) return;
    if (q.includes("coach")) navigate("/coaches?tab=applications");
    else if (q.includes("diet") || q.includes("meal"))
      navigate("/insights?tab=diet");
    else if (q.includes("work") || q.includes("exercise"))
      navigate("/insights?tab=workouts");
    else if (q.includes("appoint")) navigate("/appointments");
    else if (q.includes("report") || q.includes("analy"))
      navigate("/insights?tab=reports");
    else if (q.includes("progress")) navigate("/insights?tab=progress");
    else navigate(`/users?q=${encodeURIComponent(search.trim())}`);
  }

  const sidebarWidth = collapsed ? "w-[84px]" : "w-[272px]";

  return (
    <div className="min-h-screen bg-[var(--vf-bg)] text-[var(--vf-text)]">
      {mobileOpen ? (
        <button
          type="button"
          className="fixed inset-0 z-40 bg-slate-950/45 md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      ) : null}

      <aside
        className={`fixed inset-y-0 left-0 z-50 flex flex-col border-r border-[var(--vf-sidebar-border)] bg-[var(--vf-sidebar)] transition-all duration-300 ${sidebarWidth} ${
          mobileOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        }`}
      >
        <div className="flex h-16 items-center justify-between border-b border-[var(--vf-sidebar-border)] px-4">
          <BrandMark size="sm" showText={!collapsed} light={isDark} />
          <button
            type="button"
            className="rounded-lg p-2 text-[var(--vf-sidebar-text)] hover:bg-[var(--vf-sidebar-hover)] md:hidden"
            onClick={() => setMobileOpen(false)}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto p-3">
          {NAV.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                title={item.label}
                className={({ isActive }) =>
                  `group flex items-center gap-3 rounded-md px-2.5 py-2 text-sm transition ${
                    isActive
                      ? "bg-[var(--vf-sidebar-active-bg)] font-semibold text-[var(--vf-sidebar-active-text)]"
                      : "font-medium text-[var(--vf-sidebar-text)] hover:bg-[var(--vf-sidebar-hover)] hover:text-[var(--vf-sidebar-active-text)]"
                  }`
                }
              >
                <Icon className="h-5 w-5 shrink-0" />
                {!collapsed ? (
                  <span className="truncate">{item.label}</span>
                ) : null}
                {!collapsed && item.to === "/coaches" && pendingApps > 0 ? (
                  <span className="ml-auto rounded-full bg-[var(--vf-primary)] px-2 py-0.5 text-[10px] font-bold text-white">
                    {pendingApps}
                  </span>
                ) : null}
              </NavLink>
            );
          })}
        </nav>

        <div className="border-t border-[var(--vf-sidebar-border)] p-3">
          <button
            type="button"
            onClick={() => setCollapsed((v) => !v)}
            className="mb-2 hidden w-full items-center justify-center gap-2 rounded-[12px] border border-[var(--vf-sidebar-border)] px-3 py-2 text-sm text-[var(--vf-sidebar-text)] hover:bg-[var(--vf-sidebar-hover)] hover:text-[var(--vf-sidebar-active-text)] md:flex"
          >
            {collapsed ? (
              <PanelLeftOpen className="h-4 w-4" />
            ) : (
              <PanelLeftClose className="h-4 w-4" />
            )}
            {!collapsed ? "Collapse" : null}
          </button>
          {!collapsed ? (
            <div className="rounded-[12px] bg-[var(--vf-sidebar-hover)] p-3">
              <p className="truncate text-sm font-semibold text-[var(--vf-sidebar-active-text)]">
                {user?.full_name || user?.username}
              </p>
              <p className="truncate text-xs text-[var(--vf-sidebar-muted)]">
                @{user?.username}
              </p>
            </div>
          ) : null}
        </div>
      </aside>

      <div
        className={`transition-all duration-300 ${collapsed ? "md:pl-[84px]" : "md:pl-[272px]"}`}
      >
        <header className="sticky top-0 z-30 border-b border-[var(--vf-border)] bg-white dark:bg-[var(--vf-surface)]">
          <div className="flex h-16 items-center gap-3 px-4 md:px-6">
            <button
              type="button"
              className="rounded-lg p-2 text-[var(--vf-muted)] hover:bg-[var(--vf-surface-muted)] md:hidden"
              onClick={() => setMobileOpen(true)}
            >
              <Menu className="h-5 w-5" />
            </button>

            <div className="hidden min-w-0 md:block">
              <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-[var(--vf-primary)]">
                Vital Fitness
              </p>
              <h2 className="truncate text-base font-bold">{pageTitle}</h2>
            </div>

            <form
              onSubmit={onSearchSubmit}
              className="relative ml-auto hidden min-w-[220px] max-w-md flex-1 lg:block"
            >
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--vf-muted)]" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search users, coaches, diet…"
                className="w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] py-2.5 pl-10 pr-3 text-sm outline-none ring-[var(--vf-accent)] focus:ring-2"
              />
            </form>

            <div className="ml-auto flex items-center gap-1 md:ml-0">
              <Button
                variant="ghost"
                size="sm"
                onClick={toggleTheme}
                aria-label="Toggle theme"
              >
                {isDark ? (
                  <Sun className="h-4 w-4" />
                ) : (
                  <Moon className="h-4 w-4" />
                )}
              </Button>

              <div className="relative">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setNotifOpen((v) => !v);
                    setProfileOpen(false);
                  }}
                  aria-label="Notifications"
                >
                  <Bell className="h-4 w-4" />
                  {pendingApps > 0 ? (
                    <span className="absolute right-1 top-1 h-2 w-2 rounded-full bg-[var(--vf-danger)]" />
                  ) : null}
                </Button>
                {notifOpen ? (
                  <div className="absolute right-0 mt-2 w-80 rounded-[16px] border border-[var(--vf-border)] bg-[var(--vf-surface)] p-3 shadow-xl vf-animate-in">
                    <p className="mb-2 text-sm font-bold">Notifications</p>
                    <div className="space-y-2">
                      {pendingApps > 0 ? (
                        <button
                          type="button"
                          className="w-full rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-3 text-left text-sm hover:bg-[color-mix(in_srgb,var(--vf-primary)_8%,transparent)]"
                          onClick={() => navigate("/coaches?tab=applications")}
                        >
                          <span className="font-semibold text-[var(--vf-text)]">
                            {pendingApps} pending coach application
                            {pendingApps > 1 ? "s" : ""}
                          </span>
                          <span className="mt-1 block text-xs text-[var(--vf-muted)]">
                            Approve or reject coach registrations
                          </span>
                        </button>
                      ) : (
                        <p className="px-2 py-6 text-center text-sm text-[var(--vf-muted)]">
                          No new notifications
                        </p>
                      )}
                    </div>
                  </div>
                ) : null}
              </div>

              <div className="relative">
                <button
                  type="button"
                  onClick={() => {
                    setProfileOpen((v) => !v);
                    setNotifOpen(false);
                  }}
                  className="ml-1 flex items-center gap-2 rounded-[12px] px-2 py-1.5 text-[var(--vf-text)] hover:bg-[var(--vf-surface-muted)]"
                  aria-label="Account menu"
                >
                  <User
                    className="h-5 w-5 text-[var(--vf-primary)]"
                    strokeWidth={2}
                  />
                  <div className="hidden text-left sm:block">
                    <p className="max-w-[120px] truncate text-xs font-bold">
                      {user?.full_name || user?.username}
                    </p>
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-[var(--vf-muted)]">
                      Admin
                    </p>
                  </div>
                </button>
                {profileOpen ? (
                  <div className="absolute right-0 mt-2 w-56 rounded-[16px] border border-[var(--vf-border)] bg-[var(--vf-surface)] p-2 shadow-xl vf-animate-in">
                    <div className="border-b border-[var(--vf-border)] px-3 py-2">
                      <p className="truncate text-sm font-bold">{user?.full_name || user?.username}</p>
                      <p className="truncate text-xs text-[var(--vf-muted)]">
                        @{user?.username}
                      </p>
                      <div className="mt-2">
                        <Badge tone="primary">admin</Badge>
                      </div>
                    </div>
                    <button
                      type="button"
                      className="mt-1 flex w-full items-center gap-2 rounded-[12px] px-3 py-2 text-sm font-semibold text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/30"
                      onClick={() => {
                        logout();
                        navigate("/login");
                      }}
                    >
                      <LogOut className="h-4 w-4" />
                      Sign out
                    </button>
                  </div>
                ) : null}
              </div>
            </div>
          </div>
        </header>

        <main className="p-4 md:p-6 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
