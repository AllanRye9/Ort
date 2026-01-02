import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Properties from './pages/Properties';
import Clients from './pages/Clients';
import Users from './pages/Users';
import Listings from './pages/Listings';
import Appointments from './pages/Appointments';
import Inquiries from './pages/Inquiries';
import Transactions from './pages/Transactions';
import Payments from './pages/Payments';
import Login from './pages/Login';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/*" element={
          <Layout>
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/properties" element={<Properties />} />
              <Route path="/clients" element={<Clients />} />
              <Route path="/users" element={<Users />} />
              <Route path="/listings" element={<Listings />} />
              <Route path="/appointments" element={<Appointments />} />
              <Route path="/inquiries" element={<Inquiries />} />
              <Route path="/transactions" element={<Transactions />} />
              <Route path="/payments" element={<Payments />} />
            </Routes>
          </Layout>
        } />
      </Routes>
    </Router>
  );
}

export default App;