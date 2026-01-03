import React, { useState, useEffect } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  IconButton,
  TextField,
  Typography,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  Chip,
  Alert,
  Snackbar,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Avatar,
  Stack,
  Divider,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  AttachMoney as MoneyIcon,
  Receipt as ReceiptIcon,
  Person as PersonIcon,
  Home as HomeIcon,
  TrendingUp as TrendingUpIcon,
  TrendingDown as TrendingDownIcon,
  Download as DownloadIcon,
  Visibility as ViewIcon,
} from '@mui/icons-material';
import { transactionsAPI, propertiesAPI, usersAPI, clientsAPI } from '../services/api';
import { useForm, Controller } from 'react-hook-form';
import { DatePicker } from '@mui/x-date-pickers';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import { format } from 'date-fns';

const Transactions = () => {
  const [transactions, setTransactions] = useState([]);
  const [properties, setProperties] = useState([]);
  const [users, setUsers] = useState([]);
  const [clients, setClients] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState(null);
  const [openViewDialog, setOpenViewDialog] = useState(false);
  const [viewingTransaction, setViewingTransaction] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [transactionToDelete, setTransactionToDelete] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState(true);

  const {
    control,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm({
    defaultValues: {
      property_id: '',
      agent_id: '',
      buyer_id: '',
      sale_price: '',
      commission: '',
      transaction_date: new Date(),
    },
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [transactionsRes, propertiesRes, usersRes, clientsRes] = await Promise.all([
        transactionsAPI.getAll(),
        propertiesAPI.getAll(),
        usersAPI.getAll(),
        clientsAPI.getAll(),
      ]);
      setTransactions(transactionsRes.data);
      setProperties(propertiesRes.data);
      setUsers(usersRes.data);
      setClients(clientsRes.data);
    } catch (error) {
      showSnackbar('Error fetching data', 'error');
    } finally {
      setLoading(false);
    }
  };

  const showSnackbar = (message, severity) => {
    setSnackbar({ open: true, message, severity });
  };

  const handleOpenDialog = (transaction = null) => {
    if (transaction) {
      setEditingTransaction(transaction);
      reset({
        property_id: transaction.property_id,
        agent_id: transaction.agent_id,
        buyer_id: transaction.buyer_id,
        sale_price: transaction.sale_price,
        commission: transaction.commission || '',
        transaction_date: new Date(transaction.transaction_date),
      });
    } else {
      setEditingTransaction(null);
      reset({
        property_id: '',
        agent_id: '',
        buyer_id: '',
        sale_price: '',
        commission: '',
        transaction_date: new Date(),
      });
    }
    setOpenDialog(true);
  };

  const handleOpenViewDialog = (transaction) => {
    setViewingTransaction(transaction);
    setOpenViewDialog(true);
  };

  const handleCloseViewDialog = () => {
    setOpenViewDialog(false);
    setViewingTransaction(null);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingTransaction(null);
    reset();
  };

  const handleOpenDeleteDialog = (transaction) => {
    setTransactionToDelete(transaction);
    setOpenDeleteDialog(true);
  };

  const handleCloseDeleteDialog = () => {
    setOpenDeleteDialog(false);
    setTransactionToDelete(null);
  };

  const onSubmit = async (data) => {
    try {
      if (editingTransaction) {
        // Since we don't have update endpoint yet, show info
        showSnackbar('Update functionality not implemented yet', 'info');
      } else {
        await transactionsAPI.create(data);
        showSnackbar('Transaction created successfully', 'success');
      }
      fetchData();
      handleCloseDialog();
    } catch (error) {
      showSnackbar(`Error ${editingTransaction ? 'updating' : 'creating'} transaction`, 'error');
    }
  };

  const handleDelete = async () => {
    try {
      // Since we don't have delete endpoint yet, show info
      showSnackbar('Delete functionality not implemented yet', 'info');
      handleCloseDeleteDialog();
    } catch (error) {
      showSnackbar('Error deleting transaction', 'error');
    }
  };

  const getPropertyTitle = (propertyId) => {
    const property = properties.find(p => p.id === propertyId);
    return property ? property.title : 'Unknown Property';
  };

  const getUserName = (userId) => {
    const user = users.find(u => u.id === userId);
    return user ? `${user.first_name} ${user.last_name}` : 'Unknown Agent';
  };

  const getClientName = (clientId) => {
    const client = clients.find(c => c.id === clientId);
    return client ? `${client.first_name} ${client.last_name}` : 'Unknown Client';
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  };

  const calculateCommissionAmount = (salePrice, commissionPercent) => {
    if (!commissionPercent) return 0;
    return (parseFloat(salePrice) * parseFloat(commissionPercent)) / 100;
  };

  const getTotalRevenue = () => {
    return transactions.reduce((total, transaction) => {
      return total + parseFloat(transaction.sale_price);
    }, 0);
  };

  const getTotalCommission = () => {
    return transactions.reduce((total, transaction) => {
      const commission = parseFloat(transaction.commission) || 0;
      return total + (parseFloat(transaction.sale_price) * commission) / 100;
    }, 0);
  };

  const getAverageSalePrice = () => {
    if (transactions.length === 0) return 0;
    return getTotalRevenue() / transactions.length;
  };

  return (
    <LocalizationProvider dateAdapter={AdapterDateFns}>
      <Box>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h4">Transactions</Typography>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            New Transaction
          </Button>
        </Box>

        {/* Statistics Cards */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: 'success.main', mr: 2 }}>
                    <TrendingUpIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Total Revenue
                    </Typography>
                    <Typography variant="h5">
                      {formatCurrency(getTotalRevenue())}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: 'primary.main', mr: 2 }}>
                    <MoneyIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Total Commission
                    </Typography>
                    <Typography variant="h5">
                      {formatCurrency(getTotalCommission())}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: 'warning.main', mr: 2 }}>
                    <ReceiptIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Total Transactions
                    </Typography>
                    <Typography variant="h5">
                      {transactions.length}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: 'info.main', mr: 2 }}>
                    <HomeIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Avg. Sale Price
                    </Typography>
                    <Typography variant="h5">
                      {formatCurrency(getAverageSalePrice())}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Transactions Table */}
        <Card>
          <CardContent>
            <TableContainer component={Paper} variant="outlined">
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Date</TableCell>
                    <TableCell>Property</TableCell>
                    <TableCell>Agent</TableCell>
                    <TableCell>Buyer</TableCell>
                    <TableCell align="right">Sale Price</TableCell>
                    <TableCell align="right">Commission</TableCell>
                    <TableCell align="right">Commission Amount</TableCell>
                    <TableCell align="center">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {transactions.map((transaction) => {
                    const commissionAmount = calculateCommissionAmount(
                      transaction.sale_price,
                      transaction.commission
                    );
                    
                    return (
                      <TableRow key={transaction.id} hover>
                        <TableCell>
                          <Typography variant="body2">
                            {format(new Date(transaction.transaction_date), 'MMM dd, yyyy')}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center' }}>
                            <HomeIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary' }} />
                            <Typography variant="body2">
                              {getPropertyTitle(transaction.property_id)}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center' }}>
                            <PersonIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary' }} />
                            <Typography variant="body2">
                              {getUserName(transaction.agent_id)}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center' }}>
                            <PersonIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary' }} />
                            <Typography variant="body2">
                              {getClientName(transaction.buyer_id)}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell align="right">
                          <Typography variant="body2" fontWeight="bold">
                            {formatCurrency(transaction.sale_price)}
                          </Typography>
                        </TableCell>
                        <TableCell align="right">
                          <Chip
                            label={`${transaction.commission || 0}%`}
                            size="small"
                            color="primary"
                            variant="outlined"
                          />
                        </TableCell>
                        <TableCell align="right">
                          <Typography variant="body2" color="success.main">
                            {formatCurrency(commissionAmount)}
                          </Typography>
                        </TableCell>
                        <TableCell align="center">
                          <Stack direction="row" spacing={1} justifyContent="center">
                            <IconButton
                              size="small"
                              color="info"
                              onClick={() => handleOpenViewDialog(transaction)}
                              title="View Details"
                            >
                              <ViewIcon />
                            </IconButton>
                            <IconButton
                              size="small"
                              color="secondary"
                              onClick={() => handleOpenDialog(transaction)}
                              title="Edit"
                            >
                              <EditIcon />
                            </IconButton>
                            <IconButton
                              size="small"
                              color="error"
                              onClick={() => handleOpenDeleteDialog(transaction)}
                              title="Delete"
                            >
                              <DeleteIcon />
                            </IconButton>
                          </Stack>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>

        {/* Add/Edit Dialog */}
        <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
          <DialogTitle>
            {editingTransaction ? 'Edit Transaction' : 'New Transaction'}
          </DialogTitle>
          <form onSubmit={handleSubmit(onSubmit)}>
            <DialogContent>
              <Grid container spacing={3}>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="property_id"
                    control={control}
                    rules={{ required: 'Property is required' }}
                    render={({ field }) => (
                      <FormControl fullWidth error={!!errors.property_id}>
                        <InputLabel>Property</InputLabel>
                        <Select {...field} label="Property">
                          {properties.map((property) => (
                            <MenuItem key={property.id} value={property.id}>
                              {property.title} - {formatCurrency(property.price)}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="agent_id"
                    control={control}
                    rules={{ required: 'Agent is required' }}
                    render={({ field }) => (
                      <FormControl fullWidth error={!!errors.agent_id}>
                        <InputLabel>Agent</InputLabel>
                        <Select {...field} label="Agent">
                          {users.filter(user => user.role === 'agent').map((user) => (
                            <MenuItem key={user.id} value={user.id}>
                              {user.first_name} {user.last_name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="buyer_id"
                    control={control}
                    rules={{ required: 'Buyer is required' }}
                    render={({ field }) => (
                      <FormControl fullWidth error={!!errors.buyer_id}>
                        <InputLabel>Buyer</InputLabel>
                        <Select {...field} label="Buyer">
                          {clients.filter(client => client.client_type === 'buyer').map((client) => (
                            <MenuItem key={client.id} value={client.id}>
                              {client.first_name} {client.last_name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="sale_price"
                    control={control}
                    rules={{
                      required: 'Sale price is required',
                      min: { value: 0, message: 'Price must be positive' },
                    }}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Sale Price"
                        type="number"
                        fullWidth
                        InputProps={{ startAdornment: '$' }}
                        error={!!errors.sale_price}
                        helperText={errors.sale_price?.message}
                      />
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="commission"
                    control={control}
                    rules={{
                      min: { value: 0, message: 'Commission must be positive' },
                      max: { value: 100, message: 'Commission cannot exceed 100%' },
                    }}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Commission %"
                        type="number"
                        fullWidth
                        InputProps={{ endAdornment: '%' }}
                        error={!!errors.commission}
                        helperText={errors.commission?.message}
                      />
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="transaction_date"
                    control={control}
                    rules={{ required: 'Transaction date is required' }}
                    render={({ field }) => (
                      <DatePicker
                        label="Transaction Date"
                        value={field.value}
                        onChange={field.onChange}
                        renderInput={(params) => (
                          <TextField
                            {...params}
                            fullWidth
                            error={!!errors.transaction_date}
                            helperText={errors.transaction_date?.message}
                          />
                        )}
                      />
                    )}
                  />
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={handleCloseDialog}>Cancel</Button>
              <Button type="submit" variant="contained">
                {editingTransaction ? 'Update' : 'Create'}
              </Button>
            </DialogActions>
          </form>
        </Dialog>

        {/* View Transaction Dialog */}
        <Dialog open={openViewDialog} onClose={handleCloseViewDialog} maxWidth="sm" fullWidth>
          {viewingTransaction && (
            <>
              <DialogTitle>
                Transaction Details
                <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
                  ID: {viewingTransaction.id}
                </Typography>
              </DialogTitle>
              <DialogContent>
                <Grid container spacing={3}>
                  <Grid item xs={12}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Property
                    </Typography>
                    <Typography variant="body1" sx={{ mb: 2 }}>
                      {getPropertyTitle(viewingTransaction.property_id)}
                    </Typography>
                  </Grid>
                  
                  <Grid item xs={12} sm={6}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Agent
                    </Typography>
                    <Typography variant="body1">
                      {getUserName(viewingTransaction.agent_id)}
                    </Typography>
                  </Grid>
                  
                  <Grid item xs={12} sm={6}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Buyer
                    </Typography>
                    <Typography variant="body1">
                      {getClientName(viewingTransaction.buyer_id)}
                    </Typography>
                  </Grid>

                  <Grid item xs={12}>
                    <Divider sx={{ my: 2 }} />
                  </Grid>

                  <Grid item xs={12} sm={6}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Sale Price
                    </Typography>
                    <Typography variant="h6" color="primary">
                      {formatCurrency(viewingTransaction.sale_price)}
                    </Typography>
                  </Grid>
                  
                  <Grid item xs={12} sm={6}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Commission
                    </Typography>
                    <Typography variant="h6">
                      {viewingTransaction.commission || 0}%
                    </Typography>
                  </Grid>

                  <Grid item xs={12}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Commission Amount
                    </Typography>
                    <Typography variant="h6" color="success.main">
                      {formatCurrency(
                        calculateCommissionAmount(
                          viewingTransaction.sale_price,
                          viewingTransaction.commission
                        )
                      )}
                    </Typography>
                  </Grid>

                  <Grid item xs={12}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Transaction Date
                    </Typography>
                    <Typography variant="body1">
                      {format(new Date(viewingTransaction.transaction_date), 'PPP')}
                    </Typography>
                  </Grid>
                </Grid>
              </DialogContent>
              <DialogActions>
                <Button onClick={handleCloseViewDialog}>Close</Button>
                <Button
                  variant="outlined"
                  startIcon={<DownloadIcon />}
                  onClick={() => showSnackbar('Export functionality not implemented yet', 'info')}
                >
                  Export Receipt
                </Button>
              </DialogActions>
            </>
          )}
        </Dialog>

        {/* Delete Confirmation Dialog */}
        <Dialog open={openDeleteDialog} onClose={handleCloseDeleteDialog}>
          <DialogTitle>Confirm Delete</DialogTitle>
          <DialogContent>
            Are you sure you want to delete this transaction?
            <Typography variant="body2" color="error" sx={{ mt: 1 }}>
              This action cannot be undone.
            </Typography>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseDeleteDialog}>Cancel</Button>
            <Button onClick={handleDelete} color="error" variant="contained">
              Delete
            </Button>
          </DialogActions>
        </Dialog>

        {/* Snackbar */}
        <Snackbar
          open={snackbar.open}
          autoHideDuration={6000}
          onClose={() => setSnackbar({ ...snackbar, open: false })}
        >
          <Alert
            onClose={() => setSnackbar({ ...snackbar, open: false })}
            severity={snackbar.severity}
          >
            {snackbar.message}
          </Alert>
        </Snackbar>
      </Box>
    </LocalizationProvider>
  );
};

export default Transactions;