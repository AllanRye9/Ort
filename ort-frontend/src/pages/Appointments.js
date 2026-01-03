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
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  CalendarToday as CalendarIcon,
  AccessTime as TimeIcon,
} from '@mui/icons-material';
import { appointmentsAPI, propertiesAPI, usersAPI, clientsAPI } from '../services/api';
import { useForm, Controller } from 'react-hook-form';
import { DateTimePicker } from '@mui/x-date-pickers';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';

const Appointments = () => {
  const [appointments, setAppointments] = useState([]);
  const [properties, setProperties] = useState([]);
  const [users, setUsers] = useState([]);
  const [clients, setClients] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingAppointment, setEditingAppointment] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [appointmentToDelete, setAppointmentToDelete] = useState(null);
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
      client_id: '',
      appointment_date: new Date(),
    },
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [appointmentsRes, propertiesRes, usersRes, clientsRes] = await Promise.all([
        appointmentsAPI.getAll(),
        propertiesAPI.getAll(),
        usersAPI.getAll(),
        clientsAPI.getAll(),
      ]);
      setAppointments(appointmentsRes.data);
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

  const handleOpenDialog = (appointment = null) => {
    if (appointment) {
      setEditingAppointment(appointment);
      reset({
        ...appointment,
        appointment_date: new Date(appointment.appointment_date),
      });
    } else {
      setEditingAppointment(null);
      reset({
        property_id: '',
        agent_id: '',
        client_id: '',
        appointment_date: new Date(),
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingAppointment(null);
    reset();
  };

  const handleOpenDeleteDialog = (appointment) => {
    setAppointmentToDelete(appointment);
    setOpenDeleteDialog(true);
  };

  const handleCloseDeleteDialog = () => {
    setOpenDeleteDialog(false);
    setAppointmentToDelete(null);
  };

  const onSubmit = async (data) => {
    try {
      if (editingAppointment) {
        // Since we don't have update endpoint yet, we'll show an error
        showSnackbar('Update functionality not implemented yet', 'error');
      } else {
        await appointmentsAPI.create(data);
        showSnackbar('Appointment created successfully', 'success');
      }
      fetchData();
      handleCloseDialog();
    } catch (error) {
      showSnackbar(`Error ${editingAppointment ? 'updating' : 'creating'} appointment`, 'error');
    }
  };

  const handleDelete = async () => {
    try {
      // Since we don't have delete endpoint yet, we'll show an error
      showSnackbar('Delete functionality not implemented yet', 'error');
      handleCloseDeleteDialog();
    } catch (error) {
      showSnackbar('Error deleting appointment', 'error');
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

  const getStatusColor = (status) => {
    switch (status) {
      case 'scheduled':
        return 'primary';
      case 'completed':
        return 'success';
      case 'cancelled':
        return 'error';
      default:
        return 'default';
    }
  };

  return (
    <LocalizationProvider dateAdapter={AdapterDateFns}>
      <Box>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h4">Appointments</Typography>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            Schedule Appointment
          </Button>
        </Box>

        <Grid container spacing={3}>
          {appointments.map((appointment) => (
            <Grid item xs={12} sm={6} md={4} key={appointment.id}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <CalendarIcon sx={{ mr: 2, fontSize: 40, color: 'primary.main' }} />
                    <Box>
                      <Typography variant="h6">
                        {new Date(appointment.appointment_date).toLocaleDateString()}
                      </Typography>
                      <Chip
                        label={appointment.status}
                        size="small"
                        color={getStatusColor(appointment.status)}
                        sx={{ mt: 1 }}
                      />
                    </Box>
                  </Box>
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Property
                    </Typography>
                    <Typography>
                      {getPropertyTitle(appointment.property_id)}
                    </Typography>
                  </Box>
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Agent
                    </Typography>
                    <Typography>
                      {getUserName(appointment.agent_id)}
                    </Typography>
                  </Box>
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="subtitle2" color="textSecondary">
                      Client
                    </Typography>
                    <Typography>
                      {getClientName(appointment.client_id)}
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <TimeIcon sx={{ mr: 1, fontSize: 16 }} />
                    <Typography variant="body2" color="textSecondary">
                      {new Date(appointment.appointment_date).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
                    <IconButton
                      size="small"
                      color="secondary"
                      onClick={() => handleOpenDialog(appointment)}
                    >
                      <EditIcon />
                    </IconButton>
                    <IconButton
                      size="small"
                      color="error"
                      onClick={() => handleOpenDeleteDialog(appointment)}
                    >
                      <DeleteIcon />
                    </IconButton>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>

        {/* Add/Edit Dialog */}
        <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
          <DialogTitle>
            {editingAppointment ? 'Edit Appointment' : 'Schedule New Appointment'}
          </DialogTitle>
          <form onSubmit={handleSubmit(onSubmit)}>
            <DialogContent>
              <Grid container spacing={2}>
                <Grid item xs={12}>
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
                              {property.title}
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
                    name="appointment_date"
                    control={control}
                    rules={{ required: 'Appointment date is required' }}
                    render={({ field }) => (
                      <DateTimePicker
                        label="Appointment Date & Time"
                        value={field.value}
                        onChange={field.onChange}
                        renderInput={(params) => (
                          <TextField
                            {...params}
                            fullWidth
                            error={!!errors.appointment_date}
                            helperText={errors.appointment_date?.message}
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
                {editingAppointment ? 'Update' : 'Schedule'}
              </Button>
            </DialogActions>
          </form>
        </Dialog>

        {/* Delete Confirmation Dialog */}
        <Dialog open={openDeleteDialog} onClose={handleCloseDeleteDialog}>
          <DialogTitle>Confirm Delete</DialogTitle>
          <DialogContent>
            Are you sure you want to delete this appointment?
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseDeleteDialog}>Cancel</Button>
            <Button onClick={handleDelete} color="error" variant="contained">
              Delete
            </Button>
          </DialogActions>
        </Dialog>

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

export default Appointments;