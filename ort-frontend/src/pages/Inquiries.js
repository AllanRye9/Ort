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
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Email as EmailIcon,
  Chat as ChatIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Visibility as ViewIcon,
  Person as PersonIcon,
} from '@mui/icons-material';
import { inquiriesAPI, propertiesAPI, clientsAPI } from '../services/api';
import { useForm, Controller } from 'react-hook-form';
import { format } from 'date-fns';

const Inquiries = () => {
  const [inquiries, setInquiries] = useState([]);
  const [properties, setProperties] = useState([]);
  const [clients, setClients] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingInquiry, setEditingInquiry] = useState(null);
  const [viewingInquiry, setViewingInquiry] = useState(null);
  const [openViewDialog, setOpenViewDialog] = useState(false);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [inquiryToDelete, setInquiryToDelete] = useState(null);
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
      client_id: '',
      message: '',
    },
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [inquiriesRes, propertiesRes, clientsRes] = await Promise.all([
        inquiriesAPI.getAll(),
        propertiesAPI.getAll(),
        clientsAPI.getAll(),
      ]);
      setInquiries(inquiriesRes.data);
      setProperties(propertiesRes.data);
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

  const handleOpenDialog = (inquiry = null) => {
    if (inquiry) {
      setEditingInquiry(inquiry);
      reset({
        property_id: inquiry.property_id,
        client_id: inquiry.client_id,
        message: inquiry.message,
      });
    } else {
      setEditingInquiry(null);
      reset({
        property_id: '',
        client_id: '',
        message: '',
      });
    }
    setOpenDialog(true);
  };

  const handleOpenViewDialog = (inquiry) => {
    setViewingInquiry(inquiry);
    setOpenViewDialog(true);
  };

  const handleCloseViewDialog = () => {
    setOpenViewDialog(false);
    setViewingInquiry(null);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingInquiry(null);
    reset();
  };

  const handleOpenDeleteDialog = (inquiry) => {
    setInquiryToDelete(inquiry);
    setOpenDeleteDialog(true);
  };

  const handleCloseDeleteDialog = () => {
    setOpenDeleteDialog(false);
    setInquiryToDelete(null);
  };

  const onSubmit = async (data) => {
    try {
      if (editingInquiry) {
        showSnackbar('Update functionality not implemented yet', 'info');
      } else {
        await inquiriesAPI.create(data);
        showSnackbar('Inquiry created successfully', 'success');
      }
      fetchData();
      handleCloseDialog();
    } catch (error) {
      showSnackbar(`Error ${editingInquiry ? 'updating' : 'creating'} inquiry`, 'error');
    }
  };

  const handleDelete = async () => {
    try {
      showSnackbar('Delete functionality not implemented yet', 'info');
      handleCloseDeleteDialog();
    } catch (error) {
      showSnackbar('Error deleting inquiry', 'error');
    }
  };

  const getPropertyTitle = (propertyId) => {
    const property = properties.find(p => p.id === propertyId);
    return property ? property.title : 'Unknown Property';
  };

  const getClientName = (clientId) => {
    const client = clients.find(c => c.id === clientId);
    return client ? `${client.first_name} ${client.last_name}` : 'Unknown Client';
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'new':
        return 'primary';
      case 'contacted':
        return 'success';
      case 'closed':
        return 'error';
      default:
        return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'new':
        return <EmailIcon />;
      case 'contacted':
        return <CheckCircleIcon />;
      case 'closed':
        return <CancelIcon />;
      default:
        return <ChatIcon />;
    }
  };

  const updateInquiryStatus = async (inquiryId, newStatus) => {
    try {
      showSnackbar('Update status functionality not implemented yet', 'info');
    } catch (error) {
      showSnackbar('Error updating inquiry status', 'error');
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
        <Typography variant="h4">Inquiries</Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => handleOpenDialog()}
        >
          New Inquiry
        </Button>
      </Box>

      <Grid container spacing={3}>
        {/* Summary Cards */}
        <Grid item xs={12} sm={4}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <Avatar sx={{ bgcolor: 'primary.main', mr: 2 }}>
                  <EmailIcon />
                </Avatar>
                <Box>
                  <Typography color="textSecondary" variant="body2">
                    New Inquiries
                  </Typography>
                  <Typography variant="h4">
                    {inquiries.filter(i => i.status === 'new').length}
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={4}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <Avatar sx={{ bgcolor: 'success.main', mr: 2 }}>
                  <CheckCircleIcon />
                </Avatar>
                <Box>
                  <Typography color="textSecondary" variant="body2">
                    Contacted
                  </Typography>
                  <Typography variant="h4">
                    {inquiries.filter(i => i.status === 'contacted').length}
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={4}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <Avatar sx={{ bgcolor: 'error.main', mr: 2 }}>
                  <CancelIcon />
                </Avatar>
                <Box>
                  <Typography color="textSecondary" variant="body2">
                    Closed
                  </Typography>
                  <Typography variant="h4">
                    {inquiries.filter(i => i.status === 'closed').length}
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Inquiries Table */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <TableContainer component={Paper} variant="outlined">
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell>Property</TableCell>
                      <TableCell>Client</TableCell>
                      <TableCell>Message</TableCell>
                      <TableCell>Status</TableCell>
                      <TableCell>Date</TableCell>
                      <TableCell align="center">Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {inquiries.map((inquiry) => (
                      <TableRow key={inquiry.id}>
                        <TableCell>
                          <Typography variant="body2" fontWeight="medium">
                            {getPropertyTitle(inquiry.property_id)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center' }}>
                            <PersonIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary' }} />
                            <Typography variant="body2">
                              {getClientName(inquiry.client_id)}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              maxWidth: 200,
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                            }}
                          >
                            {inquiry.message || 'No message'}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Chip
                            icon={getStatusIcon(inquiry.status)}
                            label={inquiry.status}
                            size="small"
                            color={getStatusColor(inquiry.status)}
                          />
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" color="textSecondary">
                            {format(new Date(inquiry.created_at), 'MMM dd, yyyy')}
                          </Typography>
                        </TableCell>
                        <TableCell align="center">
                          <Stack direction="row" spacing={1} justifyContent="center">
                            <IconButton
                              size="small"
                              color="info"
                              onClick={() => handleOpenViewDialog(inquiry)}
                            >
                              <ViewIcon />
                            </IconButton>
                            <IconButton
                              size="small"
                              color="primary"
                              onClick={() => updateInquiryStatus(inquiry.id, 'contacted')}
                              title="Mark as contacted"
                            >
                              <CheckCircleIcon />
                            </IconButton>
                            <IconButton
                              size="small"
                              color="error"
                              onClick={() => updateInquiryStatus(inquiry.id, 'closed')}
                              title="Mark as closed"
                            >
                              <CancelIcon />
                            </IconButton>
                            <IconButton
                              size="small"
                              color="error"
                              onClick={() => handleOpenDeleteDialog(inquiry)}
                            >
                              <DeleteIcon />
                            </IconButton>
                          </Stack>
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

      {/* Add/Edit Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingInquiry ? 'Edit Inquiry' : 'New Inquiry'}
        </DialogTitle>
        <form onSubmit={handleSubmit(onSubmit)}>
          <DialogContent>
            <Grid container spacing={2}>
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
                            {property.title} - ${property.price}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  )}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <Controller
                  name="client_id"
                  control={control}
                  rules={{ required: 'Client is required' }}
                  render={({ field }) => (
                    <FormControl fullWidth error={!!errors.client_id}>
                      <InputLabel>Client</InputLabel>
                      <Select {...field} label="Client">
                        {clients.map((client) => (
                          <MenuItem key={client.id} value={client.id}>
                            {client.first_name} {client.last_name}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  )}
                />
              </Grid>
              <Grid item xs={12}>
                <Controller
                  name="message"
                  control={control}
                  render={({ field }) => (
                    <TextField
                      {...field}
                      label="Message"
                      fullWidth
                      multiline
                      rows={4}
                      placeholder="Enter inquiry details..."
                    />
                  )}
                />
              </Grid>
            </Grid>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseDialog}>Cancel</Button>
            <Button type="submit" variant="contained">
              {editingInquiry ? 'Update' : 'Submit'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* View Inquiry Dialog */}
      <Dialog open={openViewDialog} onClose={handleCloseViewDialog} maxWidth="sm" fullWidth>
        {viewingInquiry && (
          <>
            <DialogTitle>
              Inquiry Details
              <Chip
                icon={getStatusIcon(viewingInquiry.status)}
                label={viewingInquiry.status}
                color={getStatusColor(viewingInquiry.status)}
                size="small"
                sx={{ ml: 2 }}
              />
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={3}>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="textSecondary">
                    Property
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 2 }}>
                    {getPropertyTitle(viewingInquiry.property_id)}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="textSecondary">
                    Client
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 2 }}>
                    {getClientName(viewingInquiry.client_id)}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="textSecondary">
                    Message
                  </Typography>
                  <Paper
                    variant="outlined"
                    sx={{
                      p: 2,
                      mt: 1,
                      bgcolor: 'background.default',
                      minHeight: 100,
                    }}
                  >
                    <Typography variant="body1">
                      {viewingInquiry.message || 'No message provided'}
                    </Typography>
                  </Paper>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="textSecondary">
                    Inquiry Date
                  </Typography>
                  <Typography variant="body1">
                    {format(new Date(viewingInquiry.created_at), 'PPPpp')}
                  </Typography>
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={handleCloseViewDialog}>Close</Button>
              <Stack direction="row" spacing={1}>
                <Button
                  variant="outlined"
                  startIcon={<CheckCircleIcon />}
                  onClick={() => updateInquiryStatus(viewingInquiry.id, 'contacted')}
                >
                  Mark Contacted
                </Button>
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<CancelIcon />}
                  onClick={() => updateInquiryStatus(viewingInquiry.id, 'closed')}
                >
                  Mark Closed
                </Button>
              </Stack>
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={openDeleteDialog} onClose={handleCloseDeleteDialog}>
        <DialogTitle>Confirm Delete</DialogTitle>
        <DialogContent>
          Are you sure you want to delete this inquiry?
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
  );
};

export default Inquiries;