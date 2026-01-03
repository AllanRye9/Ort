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
  Home as HomeIcon,
  AttachMoney as MoneyIcon,
} from '@mui/icons-material';
import { listingsAPI, propertiesAPI } from '../services/api';
import { useForm, Controller } from 'react-hook-form';
import { DatePicker } from '@mui/x-date-pickers';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';

const Listings = () => {
  const [listings, setListings] = useState([]);
  const [properties, setProperties] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingListing, setEditingListing] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [listingToDelete, setListingToDelete] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState(true);

  const {
    control,
    handleSubmit,
    reset,
    setValue,
    formState: { errors },
  } = useForm({
    defaultValues: {
      property_id: '',
      listing_type: 'sale',
      listed_price: '',
      listing_date: new Date(),
      expiry_date: null,
    },
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [listingsRes, propertiesRes] = await Promise.all([
        listingsAPI.getAll(),
        propertiesAPI.getAll(),
      ]);
      setListings(listingsRes.data);
      setProperties(propertiesRes.data);
    } catch (error) {
      showSnackbar('Error fetching data', 'error');
    } finally {
      setLoading(false);
    }
  };

  const showSnackbar = (message, severity) => {
    setSnackbar({ open: true, message, severity });
  };

  const handleOpenDialog = (listing = null) => {
    if (listing) {
      setEditingListing(listing);
      reset({
        ...listing,
        listing_date: new Date(listing.listing_date),
        expiry_date: listing.expiry_date ? new Date(listing.expiry_date) : null,
      });
    } else {
      setEditingListing(null);
      reset({
        property_id: '',
        listing_type: 'sale',
        listed_price: '',
        listing_date: new Date(),
        expiry_date: null,
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingListing(null);
    reset();
  };

  const handleOpenDeleteDialog = (listing) => {
    setListingToDelete(listing);
    setOpenDeleteDialog(true);
  };

  const handleCloseDeleteDialog = () => {
    setOpenDeleteDialog(false);
    setListingToDelete(null);
  };

  const onSubmit = async (data) => {
    try {
      if (editingListing) {
        await listingsAPI.update(editingListing.id, data);
        showSnackbar('Listing updated successfully', 'success');
      } else {
        await listingsAPI.create(data);
        showSnackbar('Listing created successfully', 'success');
      }
      fetchData();
      handleCloseDialog();
    } catch (error) {
      showSnackbar(`Error ${editingListing ? 'updating' : 'creating'} listing`, 'error');
    }
  };

  const getPropertyTitle = (propertyId) => {
    const property = properties.find(p => p.id === propertyId);
    return property ? property.title : 'Unknown Property';
  };

  const getListingTypeColor = (type) => {
    return type === 'sale' ? 'success' : 'primary';
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount);
  };

  return (
    <LocalizationProvider dateAdapter={AdapterDateFns}>
      <Box>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h4">Listings</Typography>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            Add Listing
          </Button>
        </Box>

        <Grid container spacing={3}>
          {listings.map((listing) => (
            <Grid item xs={12} sm={6} md={4} key={listing.id}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <HomeIcon sx={{ mr: 2, fontSize: 40, color: 'primary.main' }} />
                    <Box>
                      <Typography variant="h6" noWrap>
                        {getPropertyTitle(listing.property_id)}
                      </Typography>
                      <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                        <Chip
                          label={listing.listing_type}
                          size="small"
                          color={getListingTypeColor(listing.listing_type)}
                        />
                        <Chip
                          label={`ID: ${listing.property_id}`}
                          size="small"
                          variant="outlined"
                        />
                      </Box>
                    </Box>
                  </Box>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <MoneyIcon sx={{ mr: 1, fontSize: 20, color: 'success.main' }} />
                    <Typography variant="h6">
                      {formatCurrency(listing.listed_price)}
                    </Typography>
                  </Box>
                  <Typography color="textSecondary" variant="body2">
                    Listed: {new Date(listing.listing_date).toLocaleDateString()}
                  </Typography>
                  {listing.expiry_date && (
                    <Typography color="textSecondary" variant="body2">
                      Expires: {new Date(listing.expiry_date).toLocaleDateString()}
                    </Typography>
                  )}
                  <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
                    <IconButton
                      size="small"
                      color="secondary"
                      onClick={() => handleOpenDialog(listing)}
                    >
                      <EditIcon />
                    </IconButton>
                    <IconButton
                      size="small"
                      color="error"
                      onClick={() => handleOpenDeleteDialog(listing)}
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
            {editingListing ? 'Edit Listing' : 'Add New Listing'}
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
                              {property.title} (${property.price})
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="listing_type"
                    control={control}
                    rules={{ required: 'Listing type is required' }}
                    render={({ field }) => (
                      <FormControl fullWidth error={!!errors.listing_type}>
                        <InputLabel>Listing Type</InputLabel>
                        <Select {...field} label="Listing Type">
                          <MenuItem value="sale">For Sale</MenuItem>
                          <MenuItem value="rent">For Rent</MenuItem>
                        </Select>
                      </FormControl>
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="listed_price"
                    control={control}
                    rules={{
                      required: 'Price is required',
                      min: { value: 0, message: 'Price must be positive' },
                    }}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Listed Price"
                        type="number"
                        fullWidth
                        InputProps={{ startAdornment: '$' }}
                        error={!!errors.listed_price}
                        helperText={errors.listed_price?.message}
                      />
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="listing_date"
                    control={control}
                    rules={{ required: 'Listing date is required' }}
                    render={({ field }) => (
                      <DatePicker
                        label="Listing Date"
                        value={field.value}
                        onChange={field.onChange}
                        renderInput={(params) => (
                          <TextField
                            {...params}
                            fullWidth
                            error={!!errors.listing_date}
                            helperText={errors.listing_date?.message}
                          />
                        )}
                      />
                    )}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Controller
                    name="expiry_date"
                    control={control}
                    render={({ field }) => (
                      <DatePicker
                        label="Expiry Date (Optional)"
                        value={field.value}
                        onChange={field.onChange}
                        renderInput={(params) => (
                          <TextField {...params} fullWidth />
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
                {editingListing ? 'Update' : 'Create'}
              </Button>
            </DialogActions>
          </form>
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

export default Listings;