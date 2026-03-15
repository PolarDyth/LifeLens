import { useState, useEffect } from "react";
import { apiClient } from "@/lib/api";
import { Dashboard } from "@/pages/Dashboard";
import { Health } from "@/pages/Health";
import { Productivity } from "@/pages/Productivity";
import { Location } from "@/pages/Location";

function App() {
  const [activePage, setActivePage] = useState<"dashboard" | "health" | "productivity" | "location">("dashboard");
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    // Check system preference for dark mode
    const darkModeQuery = window.matchMedia("(prefers-color-scheme: dark)");
    setIsDarkMode(darkModeQuery.matches);

    const handleChange = (e: MediaQueryListEvent) => setIsDarkMode(e.matches);
    darkModeQuery.addEventListener("change", handleChange);
    return () => darkModeQuery.removeEventListener("change", handleChange);
  }, []);

  useEffect(() => {
    // Apply dark mode class
    if (isDarkMode) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [isDarkMode]);

  return (
    <div className="min-h-screen bg-background text-foreground">
      <nav className="border-b bg-card">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold">LifeLens</h1>
            <div className="flex items-center gap-4">
              <span className="text-sm text-muted-foreground">
                Last updated: {lastUpdated ? lastUpdated.toLocaleTimeString() : "Never"}
              </span>
              <button
                onClick={() => setIsDarkMode(!isDarkMode)}
                className="px-3 py-1 text-sm border rounded-md hover:bg-accent"
              >
                {isDarkMode ? "☀️" : "🌙"}
              </button>
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button
              onClick={() => setActivePage("dashboard")}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activePage === "dashboard"
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-accent"
              }`}
            >
              Dashboard
            </button>
            <button
              onClick={() => setActivePage("health")}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activePage === "health"
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-accent"
              }`}
            >
              Health
            </button>
            <button
              onClick={() => setActivePage("productivity")}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activePage === "productivity"
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-accent"
              }`}
            >
              Productivity
            </button>
            <button
              onClick={() => setActivePage("location")}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activePage === "location"
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-accent"
              }`}
            >
              Location
            </button>
          </div>
        </div>
      </nav>

      <main className="container mx-auto px-4 py-8">
        {activePage === "dashboard" && <Dashboard onUpdate={setLastUpdated} />}
        {activePage === "health" && <Health onUpdate={setLastUpdated} />}
        {activePage === "productivity" && <Productivity onUpdate={setLastUpdated} />}
        {activePage === "location" && <Location onUpdate={setLastUpdated} />}
      </main>
    </div>
  );
}

export default App;
