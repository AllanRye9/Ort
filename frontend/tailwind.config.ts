import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', 'Arial', 'sans-serif'],
        display: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        serif: ['Playfair Display', 'Georgia', 'Times New Roman', 'serif'],
      },
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        brand: {
          50: '#fdf3f2',
          100: '#fce4e1',
          200: '#f8c9c2',
          300: '#f0a297',
          400: '#e4715f',
          500: '#d14a36',
          600: '#b7291b',
          700: '#951f15',
          800: '#7a1c15',
          900: '#651a15',
        },
        premium: {
          navy: '#7a1c15',
          gold: '#C5A059',
          'gold-light': '#D4B87A',
          'gold-dark': '#A8863D',
          red: '#7a1c15',
          cream: '#FAF8F5',
          charcoal: '#2b2320',
        },
        theme: {
          DEFAULT: '#B7291B',
          light: '#FCE4E1',
          dark: '#7A1C15',
        },
        success: {
          DEFAULT: '#10B981',
          light: '#D1FAE5',
          dark: '#059669',
        },
        warning: {
          DEFAULT: '#F59E0B',
          light: '#FEF3C7',
          dark: '#D97706',
        },
        error: {
          DEFAULT: '#EF4444',
          light: '#FEE2E2',
          dark: '#DC2626',
        },
        info: {
          DEFAULT: '#3B82F6',
          light: '#DBEAFE',
          dark: '#2563EB',
        },
      },
      animation: {
        'fade-in': 'fadeIn 0.4s ease-out',
        'fade-up': 'fadeUp 0.5s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'shimmer': 'shimmer 1.4s ease-in-out infinite',
        'ticker': 'ticker 30s linear infinite',
        'float': 'float 6s ease-in-out infinite',
        'pulse-glow': 'pulseGlow 2s ease-in-out infinite',
        'bounce-subtle': 'bounceSlight 2s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          from: { opacity: '0' },
          to: { opacity: '1' },
        },
        fadeUp: {
          from: { opacity: '0', transform: 'translateY(16px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        slideDown: {
          from: { opacity: '0', transform: 'translateY(-10px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        scaleIn: {
          from: { opacity: '0', transform: 'scale(0.95)' },
          to: { opacity: '1', transform: 'scale(1)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-400px 0' },
          '100%': { backgroundPosition: '400px 0' },
        },
        ticker: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(-50%)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-8px)' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgb(183 41 27 / 0.4)' },
          '50%': { boxShadow: '0 0 0 8px rgb(183 41 27 / 0)' },
        },
        bounceSlight: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-6px)' },
        },
      },
      boxShadow: {
        'glow': '0 0 20px rgb(183 41 27 / 0.25)',
        'glow-lg': '0 0 40px rgb(183 41 27 / 0.3)',
        'card': '0 1px 3px 0 rgb(0 0 0 / 0.08), 0 1px 2px -1px rgb(0 0 0 / 0.06)',
        'card-hover': '0 20px 25px -5px rgb(0 0 0 / 0.08), 0 8px 10px -6px rgb(0 0 0 / 0.04)',
      },
      backgroundImage: {
        'hero-gradient': 'linear-gradient(135deg, #951f15 0%, #7a1c15 40%, #5c1610 100%)',
        'brand-gradient': 'linear-gradient(135deg, #b7291b, #7a1c15)',
        'premium-gradient': 'linear-gradient(135deg, #b7291b 0%, #951f15 50%, #5c1610 100%)',
        'theme-gradient': 'linear-gradient(135deg, #1a1a1a 0%, #7a1c15 50%, #b7291b 100%)',
        'theme-gradient-soft': 'linear-gradient(160deg, #fdf6ee 0%, #fbeee2 40%, #fdf3f2 70%, #fdf8f0 100%)',
      },
      screens: {
        'xs': '375px',
      },
    },
  },
  plugins: [],
};
export default config;
