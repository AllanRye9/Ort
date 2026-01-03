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
  LinearProgress,
  Tooltip,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  AttachMoney as MoneyIcon,
  Receipt as ReceiptIcon,
  CreditCard as CreditCardIcon,
  AccountBalance as BankIcon,
  Paid as PaidIcon,
  Pending as PendingIcon,
  Download as DownloadIcon,
  Visibility as ViewIcon,
  TrendingUp as TrendingUpIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
} from '@mui/icons-material';
import { paymentsAPI, transactionsAPI } from '../services/api';
import { useForm, Controller } from 'react-hook-form';
import { DatePicker } from '@mui/x-date-pickers';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import { format } from 'date-fns';

const Payments = () => {
  const [payments, setPayments] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingPayment, setEditingPayment] = useState(null);
  const [openViewDialog, setOpenViewDialog] = useState(false);
  const [viewingPayment, setViewingPayment] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [paymentToDelete, setPaymentToDelete] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState(true);

  const {
    control,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm({
    defaultValues: {
      transaction_id: '',
      amount: '',
      payment_method: 'credit_card',
    },
  });

  const selectedTransactionId = watch('transaction_id');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [paymentsRes, transactionsRes] = await Promise.all([
        paymentsAPI.getAll(),
        transactionsAPI.getAll(),
      ]);
      setPayments(paymentsRes.data);
      setTransactions(transactionsRes.data);
    } catch (error) {
      showSnackbar('Error fetching data', 'error');
    } finally {
      setLoading(false);
    }
  };

  const showSnackbar = (message, severity) => {
    setSnackbar({ open: true, message, severity });
  };

  const handleOpenDialog = (payment = null) => {
    if (payment) {
      setEditingPayment(payment);
      reset({
        transaction_id: payment.transaction_id,
        amount: payment.amount,
        payment_method: payment.payment_method || 'credit_card',
      });
    } else {
      setEditingPayment(null);
      reset({
        transaction_id: '',
        amount: '',
        payment_method: 'credit_card',
      });
    }
    setOpenDialog(true);
  };

  const handleOpenViewDialog = (payment) => {
    setViewingPayment(payment);
    setOpenViewDialog(true);
  };

  const handleCloseViewDialog = () => {
    setOpenViewDialog(false);
    setViewingPayment(null);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingPayment(null);
    reset();
  };

  const handleOpenDeleteDialog = (payment) => {
    setPaymentToDelete(payment);
    setOpenDeleteDialog(true);
  };

  const handleCloseDeleteDialog = () => {
    setOpenDeleteDialog(false);
    setPaymentToDelete(null);
  };

  const onSubmit = async (data) => {
    try {
      if (editingPayment) {
        showSnackbar('Update functionality not implemented yet', 'info');
      } else {
        await paymentsAPI.create(data);
        showSnackbar('Payment recorded successfully', 'success');
      }
      fetchData();
      handleCloseDialog();
    } catch (error) {
      showSnackbar(`Error ${editingPayment ? 'updating' : 'creating'} payment`, 'error');
    }
  };

  const handleDelete = async () => {
    try {
      showSnackbar('Delete functionality not implemented yet', 'info');
      handleCloseDeleteDialog();
    } catch (error) {
      showSnackbar('Error deleting payment', 'error');
    }
  };

  const getTransactionInfo = (transactionId) => {
    const transaction = transactions.find(t => t.id === transactionId);
    return transaction 
      ? { 
          sale_price: transaction.sale_price,
          date: transaction.transaction_date,
        }
      : null;
  };

  const getSelectedTransactionSalePrice = () => {
    if (!selectedTransactionId) return 0;
    const transaction = getTransactionInfo(selectedTransactionId);
    return transaction ? parseFloat(transaction.sale_price) : 0;
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  };

  const getPaymentMethodIcon = (method) => {
    switch (method?.toLowerCase()) {
      case 'credit_card':
        return <CreditCardIcon />;
      case 'bank_transfer':
        return <BankIcon />;
      case 'cash':
        return <MoneyIcon />;
      case 'check':
        return <ReceiptIcon />;
      default:
        return <PaidIcon />;
    }
  };

  const getPaymentMethodColor = (method) => {
    switch (method?.toLowerCase()) {
      case 'credit_card':
        return 'primary';
      case 'bank_transfer':
        return 'success';
      case 'cash':
        return 'warning';
      case 'check':
        return 'info';
      default:
        return 'default';
    }
  };

  const getPaymentMethodLabel = (method) => {
    switch (method?.toLowerCase()) {
      case 'credit_card':
        return 'Credit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      case 'check':
        return 'Check';
      default:
        return method || 'Unknown';
    }
  };

  const getTotalPayments = () => {
    return payments.reduce((total, payment) => total + parseFloat(payment.amount), 0);
  };

  const getRecentPayments = () => {
    return payments
      .sort((a, b) => new Date(b.payment_date) - new Date(a.payment_date))
      .slice(0, 5);
  };

  const getTransactionProgress = (transactionId) => {
    const transaction = getTransactionInfo(transactionId);
    if (!transaction) return 0;
    
    const totalPaid = payments
      .filter(p => p.transaction_id === transactionId)
      .reduce((sum, p) => sum + parseFloat(p.amount), 0);
    
    return (totalPaid / parseFloat(transaction.sale_price)) * 100;
  };

  const getRemainingBalance = (transactionId) => {
    const transaction = getTransactionInfo(transactionId);
    if (!transaction) return 0;
    
    const totalPaid = payments
      .filter(p => p.transaction_id === transactionId)
      .reduce((sum, p) => sum + parseFloat(p.amount), 0);
    
    return parseFloat(transaction.sale_price) - totalPaid;
  };

  return (
    <LocalizationProvider dateAdapter={AdapterDateFns}>
      <Box>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h4">Payments</Typography>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            Record Payment
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
                      Total Received
                    </Typography>
                    <Typography variant="h5">
                      {formatCurrency(getTotalPayments())}
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
                    <PaidIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Total Payments
                    </Typography>
                    <Typography variant="h5">
                      {payments.length}
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
                    <CheckCircleIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Recent Payments
                    </Typography>
                    <Typography variant="h5">
                      {getRecentPayments().length}
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
                    <ReceiptIcon />
                  </Avatar>
                  <Box>
                    <Typography color="textSecondary" variant="body2">
                      Avg. Payment
                    </Typography>
                    <Typography variant="h5">
                      {formatCurrency(
                        payments.length > 0 
                          ? getTotalPayments() / payments.length 
                          : 0
                      )}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Recent Payments */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Recent Payments
                </Typography>
                <TableContainer component={Paper} variant="outlined">
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell>Date</TableCell>
                        <TableCell>Transaction ID</TableCell>
                        <TableCell>Amount</TableCell>
                        <TableCell>Method</TableCell>
                        <TableCell>Progress</TableCell>
                        <TableCell align="center">Actions</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {getRecentPayments().map((payment) => {
                        const progress = getTransactionProgress(payment.transaction_id);
                        const remaining = getRemainingBalance(payment.transaction_id);
                        
                        return (
                          <TableRow key={payment.id} hover>
                            <TableCell>
                              <Typography variant="body2">
                                {format(new Date(payment.payment_date), 'MMM dd, yyyy')}
                              </Typography>
                            </TableCell>
                            <TableCell>
                              <Chip
                                label={`#${payment.transaction_id}`}
                                size="small"
                                variant="outlined"
                              />
                            </TableCell>
                            <TableCell>
                              <Typography variant="body2" fontWeight="bold">
                                {formatCurrency(payment.amount)}
                              </Typography>
                            </TableCell>
                            <TableCell>
                              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                {getPaymentMethodIcon(payment.payment_method)}
                                <Typography variant="body2" sx={{ ml: 1 }}>
                                  {getPaymentMethodLabel(payment.payment_method)}
                                </Typography>
                              </Box>
                            </TableCell>
                            <TableCell>
                              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <Box sx={{ width: '100%', mr: 1 }}>
                                  <LinearProgress 
                                    variant="determinate" 
                                    value={Math.min(progress, 100)} 
                                    color={progress >= 100 ? "success" : "primary"}
                                  />
                                </Box>
                                <Typography variant="body2" color="textSecondary">
                                  {Math.round(progress)}%
                                </Typography>
                              </Box>
                              {remaining > 0 && (
                                <Typography variant="caption" color="textSecondary">
                                  {formatCurrency(remaining)} remaining
                                </Typography>
                              )}
                            </TableCell>
                            <TableCell align="center">
                              <Stack direction="row" spacing={1} justifyContent="center">
                                <Tooltip title="View Details">
                                  <IconButton
                                    size="small"
                                    color="info"
                                    onClick={() => handleOpenViewDialog(payment)}
                                  >
                                    <ViewIcon />
                                  </IconButton>
                                </Tooltip>
                                <Tooltip title="Edit">
                                  <IconButton
                                    size="small"
                                    color="secondary"
                                    onClick={() => handleOpenDialog(payment)}
                                  >
                                    <EditIcon />
                                  </IconButton>
                                </Tooltip>
                                <Tooltip title="Delete">
                                  <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleOpenDeleteDialog(payment)}
                                  >
                                    <DeleteIcon />
                                  </IconButton>
                                </Tooltip>
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
          </Grid>
        </Grid>

        {/* All Payments */}
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              All Payments
            </Typography>
            <TableContainer component={Paper} variant="outlined">
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>ID</TableCell>
                    <TableCell>Transaction ID</TableCell>
                    <TableCell>Amount</TableCell>
                    <TableCell>Payment Method</TableCell>
                    <TableCell>Payment Date</TableCell>
                    <TableCell align="center">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {payments.map((payment) => (
                    <TableRow key={payment.id} hover>
                      <TableCell>
                        <Typography variant="body2">
                          #{payment.id}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={`Transaction #${payment.transaction_id}`}
                          size="small"
                          color="primary"
                          variant="outlined"
                        />
                      </TableCell>
                      <TableCell>
                        <Typography variant="body1" fontWeight="bold" color="success.main">
                          {formatCurrency(payment.amount)}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Box sx={{ display: 'flex', alignItems: 'center' }}>
                          <Avatar 
                            sx={{ 
                              width: 24, 
                              height: 24, 
                              mr: 1,
                              bgcolor: `${getPaymentMethodColor(payment.payment_method)}.light`,
                              color: `${getPaymentMethodColor(payment.payment_method)}.dark`,
                            }}
                          >
                            {getPaymentMethodIcon(payment.payment_method)}
                          </Avatar>
                          <Typography variant="body2">
                            {getPaymentMethodLabel(payment.payment_method)}
                          </Typography>
                        </Box>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2">
                          {format(new Date(payment.payment_date), 'PPP')}
                        </Typography>
                      </TableCell>
                      <TableCell align="center">
                        <Stack direction="row" spacing={1} justifyContent="center">
                          <Tooltip title="View Details">
                            <IconButton
                              size="small"
                              color="info"
                              onClick={() => handleOpenViewDialog(payment)}
                            >
                              <ViewIcon />
                            </IconButton>
                          </Tooltip>
                          <Tooltip title="Edit">
                            <IconButton
                              size="small"
                              color="secondary"
                              onClick={() => handleOpenDialog(payment)}
                            >
                              <EditIcon />
                            </IconButton>
                          </Tooltip>
                          <Tooltip title="Delete">
                            <IconButton
                              size="small"
                              color="error"
                              onClick={() => handleOpenDeleteDialog(payment)}
                            >
                              <DeleteIcon />
                            </IconButton>
                          </Tooltip>
                        </Stack>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>

        {/* Add/Edit Dialog */}
        <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
          <DialogTitle>
            {editingPayment ? 'Edit Payment' : 'Record New Payment'}
          </DialogTitle>
          <form onSubmit={handleSubmit(onSubmit)}>
            <DialogContent>
              <Grid container spacing={3}>
                <Grid item xs={12}>
                  <Controller
                    name="transaction_id"
                    control={control}
                    rules={{ required: 'Transaction is required' }}
                    render={({ field }) => (
                      <FormControl fullWidth error={!!errors.transaction_id}>
                        <InputLabel>Transaction</InputLabel>
                        <Select {...field} label="Transaction">
                          {transactions.map((transaction) => (
                            <MenuItem key={transaction.id} value={transaction.id}>
                              Transaction #{transaction.id} - {formatCurrency(transaction.sale_price)}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>

                {selectedTransactionId && (
                  <>
                    <Grid item xs={12}>
                      <Divider sx={{ my: 1 }} />
                    </Grid>
                    
                    <Grid item xs={12} sm={6}>
                      <Typography variant="subtitle2" color="textSecondary">
                        Transaction Amount
                      </Typography>
                      <Typography variant="h6" color="primary">
                        {formatCurrency(getSelectedTransactionSalePrice())}
                      </Typography>
                    </Grid>
                    
                    <Grid item xs={12} sm={6}>
                      <Typography variant="subtitle2" color="textSecondary">
                        Already Paid
                      </Typography>
                      <Typography variant="h6" color="success.main">
                        {formatCurrency(
                          payments
                            .filter(p => p.transaction_id === selectedTransactionId)
                            .reduce((sum, p) => sum + parseFloat(p.amount), 0)
                        )}
                      </Typography>
                    </Grid>

                    <Grid item xs={12}>
                      <Typography variant="subtitle2" color="textSecondary">
                        Remaining Balance
                      </Typography>
                      <Typography variant="h6" color="warning.main">
                        {formatCurrency(
                          getSelectedTransactionSalePrice() - 
                          payments
                            .filter(p => p.transaction_id === selectedTransactionId)
                            .reduce((sum, p) => sum + parseFloat(p.amount), 0)
                        )}
                      </Typography>
                    </Grid>
                  </>
                )}

                <Grid item xs={12}>
                  <Divider sx={{ my: 1 }} />
                </Grid>

                <Grid item xs={12} sm={8}>
                  <Controller
                    name="amount"
                    control={control}
                    rules={{
                      required: 'Amount is required',
                      min: { value: 1, message: 'Amount must be at least $1' },
                      max: { 
                        value: selectedTransactionId ? getSelectedTransactionSalePrice() : 1000000000,
                        message: 'Amount cannot exceed transaction balance' 
                      },
                    }}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Payment Amount"
                        type="number"
                        fullWidth
                        InputProps={{ startAdornment: '$' }}
                        error={!!errors.amount}
                        helperText={errors.amount?.message}
                      />
                    )}
                  />
                </Grid>

                <Grid item xs={12} sm={4}>
                  <Controller
                    name="payment_method"
                    control={control}
                    render={({ field }) => (
                      <FormControl fullWidth>
                        <InputLabel>Method</InputLabel>
                        <Select {...field} label="Method">
                          <MenuItem value="credit_card">Credit Card</MenuItem>
                          <MenuItem value="bank_transfer">Bank Transfer</MenuItem>
                          <MenuItem value="cash">Cash</MenuItem>
                          <MenuItem value="check">Check</MenuItem>
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={handleCloseDialog}>Cancel</Button>
              <Button type="submit" variant="contained">
                {editingPayment ? 'Update' : 'Record Payment'}
              </Button>
            </DialogActions>
          </form>
        </Dialog>

        {/* View Payment Dialog */}
        <Dialog open={openViewDialog} onClose={handleCloseViewDialog} maxWidth="sm" fullWidth>
          {viewingPayment && (
            <>
              <DialogTitle>
                Payment Details
                <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
                  Payment ID: #{viewingPayment.id}
                </Typography>
              </DialogTitle>
              <DialogContent>
                <Grid container spacing={3}>
                  <Grid item xs={12}>
                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                      <Avatar 
                        sx={{ 
                          width: 40, 
                          height: 40, 
                          mr: 2,
                          bgcolor: `${getPaymentMethodColor(viewingPayment.payment_method)}.light`,
                          color: `${getPaymentMethodColor(viewingPayment.payment_method)}.dark`,
                        }}
                      >
                        {getPaymentMethodIcon(viewingPayment.payment_method)}
                      </Avatar>
                      <Box>
                        <Typography variant="h6">
                          {formatCurrency(viewingPayment.amount)}
                        </Typography>
                        <Typography variant="body2" color="textSecondary">
                          {getPaymentMethodLabel(viewingPayment.payment_method)}
                        </Typography>
                      </Box>
                    </Box>
                  </Grid>

                  <Grid item xs={12}>
                    <Divider sx={{ my: 2 }} />
                  </Grid>

                  <Grid item xs={12}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Transaction
                    </Typography>
                    <Typography variant="body1">
                      Transaction #{viewingPayment.transaction_id}
                    </Typography>
                  </Grid>

                  <Grid item xs={12}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Payment Date
                    </Typography>
                    <Typography variant="body1">
                      {format(new Date(viewingPayment.payment_date), 'PPPP')}
                    </Typography>
                  </Grid>

                  {getTransactionInfo(viewingPayment.transaction_id) && (
                    <>
                      <Grid item xs={12}>
                        <Divider sx={{ my: 2 }} />
                      </Grid>

                      <Grid item xs={12} sm={6}>
                        <Typography variant="subtitle2" color="textSecondary">
                          Transaction Amount
                        </Typography>
                        <Typography variant="body1">
                          {formatCurrency(getTransactionInfo(viewingPayment.transaction_id).sale_price)}
                        </Typography>
                      </Grid>

                      <Grid item xs={12} sm={6}>
                        <Typography variant="subtitle2" color="textSecondary">
                          Payment Progress
                        </Typography>
                        <Box sx={{ display: 'flex', alignItems: 'center' }}>
                          <Box sx={{ width: '100%', mr: 1 }}>
                            <LinearProgress 
                              variant="determinate" 
                              value={getTransactionProgress(viewingPayment.transaction_id)} 
                            />
                          </Box>
                          <Typography variant="body2">
                            {Math.round(getTransactionProgress(viewingPayment.transaction_id))}%
                          </Typography>
                        </Box>
                      </Grid>
                    </>
                  )}
                </Grid>
              </DialogContent>
              <DialogActions>
                <Button onClick={handleCloseViewDialog}>Close</Button>
                <Button
                  variant="outlined"
                  startIcon={<DownloadIcon />}
                  onClick={() => showSnackbar('Export receipt functionality not implemented yet', 'info')}
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
            Are you sure you want to delete this payment?
            <Typography variant="body2" color="error" sx={{ mt: 1 }}>
              This will remove the payment record permanently.
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

export default Payments;