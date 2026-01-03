import React, { useState, useEffect } from 'react';
import {
  Grid,
  Paper,
  Typography,
  Box,
  Card,
  CardContent,
  CardHeader,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  LinearProgress,
  Chip,
} from '@mui/material';
import {
  Home,
  People,
  AttachMoney,
  CalendarToday,
  TrendingUp,
  TrendingDown,
} from '@mui/icons-material';
import { propertiesAPI, clientsAPI, transactionsAPI, appointmentsAPI } from '../services/api';
import { format } from 'date-fns';

const StatCard = ({ title, value, icon, color, trend }) => (
  <Card>
    <CardContent>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
        <Box
          sx={{
            backgroundColor: `${color}.light`,
            borderRadius: '50%',
            p: 1,
            mr: 2,
          }}
        >
          {icon}
        </Box>
        <Box>
          <Typography color="textSecondary" variant="body2">
            {title}
          </Typography>
          <Typography variant="h4">{value}</Typography>
        </Box>
      </Box>
      {trend && (
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          {trend > 0 ? (
            <TrendingUp color="success" sx={{ mr: 0.5 }} />
          ) : (
            <TrendingDown color="error" sx={{ mr: 0.5 }} />
          )}
          <Typography
            variant="body2"
            color={trend > 0 ? 'success.main' : 'error.main'}
          >
            {trend > 0 ? '+' : ''}{trend}% from last month
          </Typography>
        </Box>
      )}
    </CardContent>
  </Card>
);

const Dashboard = () => {
  const [stats, setStats] = useState({
    properties: 0,
    clients: 0,
    revenue: 0,
    appointments: 0,
  });
  const [recentProperties, setRecentProperties] = useState([]);
  const [recentTransactions, setRecentTransactions] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      const [propertiesRes, clientsRes, transactionsRes, appointmentsRes] =
        await Promise.all([
          propertiesAPI.getAll(),
          clientsAPI.getAll(),
          transactionsAPI.getAll(),
          appointmentsAPI.getAll(),
        ]);

      const totalRevenue = transactionsRes.data.reduce(
        (sum, transaction) => sum + parseFloat(transaction.sale_price),
        0
      );

      setStats({
        properties: propertiesRes.data.length,
        clients: clientsRes.data.length,
        revenue: totalRevenue,
        appointments: appointmentsRes.data.length,
      });

      // Get recent properties
      const sortedProperties = [...propertiesRes.data]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 5);
      setRecentProperties(sortedProperties);

      // Get recent transactions
      const sortedTransactions = [...transactionsRes.data]
        .sort((a, b) => new Date(b.transaction_date) - new Date(a.transaction_date))
        .slice(0, 5);
      setRecentTransactions(sortedTransactions);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <LinearProgress />;
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>
      
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Properties"
            value={stats.properties}
            icon={<Home />}
            color="primary"
            trend={12}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Clients"
            value={stats.clients}
            icon={<People />}
            color="secondary"
            trend={8}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Revenue"
            value={`$${stats.revenue.toLocaleString()}`}
            icon={<AttachMoney />}
            color="success"
            trend={15}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Appointments"
            value={stats.appointments}
            icon={<CalendarToday />}
            color="warning"
            trend={5}
          />
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardHeader title="Recent Properties" />
            <CardContent>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Property</TableCell>
                      <TableCell>Type</TableCell>
                      <TableCell>Price</TableCell>
                      <TableCell>Status</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {recentProperties.map((property) => (
                      <TableRow key={property.id}>
                        <TableCell>{property.title}</TableCell>
                        <TableCell>{property.property_type}</TableCell>
                        <TableCell>${parseFloat(property.price).toLocaleString()}</TableCell>
                        <TableCell>
                          <Chip
                            label={property.status}
                            size="small"
                            color={
                              property.status === 'available'
                                ? 'success'
                                : property.status === 'sold'
                                ? 'error'
                                : 'warning'
                            }
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card>
            <CardHeader title="Recent Transactions" />
            <CardContent>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Date</TableCell>
                      <TableCell>Property ID</TableCell>
                      <TableCell>Amount</TableCell>
                      <TableCell>Commission</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {recentTransactions.map((transaction) => (
                      <TableRow key={transaction.id}>
                        <TableCell>
                          {format(new Date(transaction.transaction_date), 'MMM dd, yyyy')}
                        </TableCell>
                        <TableCell>#{transaction.property_id}</TableCell>
                        <TableCell>${parseFloat(transaction.sale_price).toLocaleString()}</TableCell>
                        <TableCell>
                          {transaction.commission
                            ? `$${parseFloat(transaction.commission).toLocaleString()}`
                            : '-'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;