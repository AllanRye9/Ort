/**
 * Platform API Integration Layer
 *
 * Provides typed access to the Real Estate Management API.
 *
 * Environment variables (Vite):
 *   VITE_API_BASE_URL   – Base URL of the backend (e.g. https://api.example.com)
 *   VITE_USE_MOCK_API   – When "true" (default) the module returns in-memory
 *                         mock data instead of hitting the network.
 *
 * Production usage:
 *   Set VITE_USE_MOCK_API=false and supply a valid VITE_API_BASE_URL.
 *   Every request will include an Authorization: Bearer <token> header.
 *   Call setAuthToken(token) after the user signs in.
 */

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const BASE_URL: string =
  (typeof import.meta !== "undefined" &&
    (import.meta as Record<string, unknown>).env &&
    ((import.meta as Record<string, unknown>).env as Record<string, string>)
      .VITE_API_BASE_URL) ||
  "http://localhost:8000";

const USE_MOCK: boolean =
  (typeof import.meta !== "undefined" &&
    (import.meta as Record<string, unknown>).env &&
    ((import.meta as Record<string, unknown>).env as Record<string, string>)
      .VITE_USE_MOCK_API) !== "false";

let _authToken: string | null = null;

/** Store the Bearer token that will be sent with every production request. */
export function setAuthToken(token: string | null): void {
  _authToken = token;
}

// ---------------------------------------------------------------------------
// Types — mirror the backend Pydantic schemas
// ---------------------------------------------------------------------------

export type UserRole = "agent" | "admin";
export type ClientType = "buyer" | "seller" | "renter";
export type PropertyType = "house" | "apartment" | "land" | "commercial";
export type PropertyStatus = "available" | "sold" | "rented" | "pending";
export type ListingType = "sale" | "rent";
export type InquiryStatus = "new" | "contacted" | "closed";
export type AppointmentStatus = "scheduled" | "completed" | "cancelled";

export interface User {
  id: number;
  role: UserRole;
  first_name: string;
  last_name: string;
  email: string;
  phone: string | null;
  created_at: string;
}

export interface UserCreate {
  role: UserRole;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string | null;
  password: string;
}

export interface Client {
  id: number;
  first_name: string;
  last_name: string;
  email: string | null;
  phone: string | null;
  client_type: ClientType;
  created_at: string;
}

export interface ClientCreate {
  first_name: string;
  last_name: string;
  email?: string | null;
  phone?: string | null;
  client_type: ClientType;
  agent_id?: number | null;
}

export interface Property {
  id: number;
  title: string;
  description: string | null;
  property_type: PropertyType;
  address: string;
  city: string | null;
  price: number;
  bedrooms: number | null;
  bathrooms: number | null;
  area_sqft: number | null;
  status: PropertyStatus;
  created_at: string;
}

export interface PropertyCreate {
  title: string;
  description?: string | null;
  property_type: PropertyType;
  address: string;
  city?: string | null;
  price: number;
  bedrooms?: number | null;
  bathrooms?: number | null;
  area_sqft?: number | null;
  owner_id?: number | null;
  agent_id?: number | null;
}

export interface PropertyImage {
  id: number;
  image_url: string;
  is_primary: boolean;
}

export interface PropertyImageCreate {
  property_id: number;
  image_url: string;
  is_primary?: boolean;
}

export interface Listing {
  id: number;
  listing_type: ListingType;
  listed_price: number;
  listing_date: string;
  expiry_date: string | null;
}

export interface ListingCreate {
  property_id: number;
  listing_type: ListingType;
  listed_price: number;
  listing_date: string;
  expiry_date?: string | null;
}

export interface Inquiry {
  id: number;
  message: string | null;
  status: InquiryStatus;
  created_at: string;
}

export interface InquiryCreate {
  property_id: number;
  client_id?: number | null;
  message?: string | null;
}

export interface Appointment {
  id: number;
  appointment_date: string;
  status: AppointmentStatus;
}

export interface AppointmentCreate {
  property_id: number;
  agent_id: number;
  client_id: number;
  appointment_date: string;
}

export interface Transaction {
  id: number;
  sale_price: number;
  commission: number | null;
  transaction_date: string;
}

export interface TransactionCreate {
  property_id: number;
  agent_id: number;
  buyer_id: number;
  sale_price: number;
  commission?: number | null;
  transaction_date: string;
}

export interface Payment {
  id: number;
  amount: number;
  payment_method: string | null;
  payment_date: string;
}

export interface PaymentCreate {
  transaction_id: number;
  amount: number;
  payment_method?: string | null;
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

function authHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (_authToken) {
    headers["Authorization"] = `Bearer ${_authToken}`;
  }
  return headers;
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown
): Promise<T> {
  const url = `${BASE_URL}/api/v1${path}`;
  const init: RequestInit = {
    method,
    headers: authHeaders(),
  };
  if (body !== undefined) {
    init.body = JSON.stringify(body);
  }
  const response = await fetch(url, init);
  if (!response.ok) {
    const text = await response.text().catch(() => response.statusText);
    throw new Error(`API ${method} /api/v1${path} failed [${response.status}]: ${text}`);
  }
  return response.json() as Promise<T>;
}

// ---------------------------------------------------------------------------
// Mock data store
// ---------------------------------------------------------------------------

const mockStore = {
  users: [
    {
      id: 1,
      role: "agent" as UserRole,
      first_name: "Alice",
      last_name: "Smith",
      email: "alice@example.com",
      phone: "555-0101",
      created_at: "2024-01-01T00:00:00Z",
    },
    {
      id: 2,
      role: "admin" as UserRole,
      first_name: "Bob",
      last_name: "Jones",
      email: "bob@example.com",
      phone: null,
      created_at: "2024-01-02T00:00:00Z",
    },
  ] as User[],

  clients: [
    {
      id: 1,
      first_name: "Carol",
      last_name: "White",
      email: "carol@example.com",
      phone: "555-0201",
      client_type: "buyer" as ClientType,
      created_at: "2024-01-03T00:00:00Z",
    },
    {
      id: 2,
      first_name: "Dan",
      last_name: "Brown",
      email: null,
      phone: "555-0202",
      client_type: "seller" as ClientType,
      created_at: "2024-01-04T00:00:00Z",
    },
  ] as Client[],

  properties: [
    {
      id: 1,
      title: "Modern Downtown Apartment",
      description: "Bright 2-bed in the city center",
      property_type: "apartment" as PropertyType,
      address: "1 Main St",
      city: "Nairobi",
      price: 250000,
      bedrooms: 2,
      bathrooms: 1,
      area_sqft: 900,
      status: "available" as PropertyStatus,
      created_at: "2024-01-05T00:00:00Z",
    },
    {
      id: 2,
      title: "Suburban Family House",
      description: "Spacious 4-bed with garden",
      property_type: "house" as PropertyType,
      address: "22 Oak Avenue",
      city: "Nairobi",
      price: 420000,
      bedrooms: 4,
      bathrooms: 2,
      area_sqft: 2200,
      status: "available" as PropertyStatus,
      created_at: "2024-01-06T00:00:00Z",
    },
  ] as Property[],

  propertyImages: [
    {
      id: 1,
      image_url: "https://example.com/images/apt1-main.jpg",
      is_primary: true,
    },
    {
      id: 2,
      image_url: "https://example.com/images/apt1-living.jpg",
      is_primary: false,
    },
  ] as PropertyImage[],

  listings: [
    {
      id: 1,
      listing_type: "sale" as ListingType,
      listed_price: 250000,
      listing_date: "2024-02-01",
      expiry_date: "2024-08-01",
    },
  ] as Listing[],

  inquiries: [
    {
      id: 1,
      message: "Is the apartment still available?",
      status: "new" as InquiryStatus,
      created_at: "2024-02-10T08:30:00Z",
    },
  ] as Inquiry[],

  appointments: [
    {
      id: 1,
      appointment_date: "2024-02-15T10:00:00Z",
      status: "scheduled" as AppointmentStatus,
    },
  ] as Appointment[],

  transactions: [
    {
      id: 1,
      sale_price: 250000,
      commission: 7500,
      transaction_date: "2024-03-01",
    },
  ] as Transaction[],

  payments: [
    {
      id: 1,
      amount: 50000,
      payment_method: "bank_transfer",
      payment_date: "2024-03-05",
    },
  ] as Payment[],
};

let _nextId = 100;
function nextId(): number {
  return ++_nextId;
}

function now(): string {
  return new Date().toISOString();
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Users API
// ---------------------------------------------------------------------------

export const usersApi = {
  async list(): Promise<User[]> {
    if (USE_MOCK) return [...mockStore.users];
    return request<User[]>("GET", "/users/");
  },

  async get(userId: number): Promise<User> {
    if (USE_MOCK) {
      const user = mockStore.users.find((u) => u.id === userId);
      if (!user) throw new Error(`User ${userId} not found`);
      return { ...user };
    }
    return request<User>("GET", `/users/${userId}`);
  },

  async create(data: UserCreate): Promise<User> {
    if (USE_MOCK) {
      const user: User = {
        id: nextId(),
        role: data.role,
        first_name: data.first_name,
        last_name: data.last_name,
        email: data.email,
        phone: data.phone ?? null,
        created_at: now(),
      };
      mockStore.users.push(user);
      return { ...user };
    }
    return request<User>("POST", "/users/", data);
  },

  async update(userId: number, data: UserCreate): Promise<User> {
    if (USE_MOCK) {
      const index = mockStore.users.findIndex((u) => u.id === userId);
      if (index === -1) throw new Error(`User ${userId} not found`);
      mockStore.users[index] = {
        ...mockStore.users[index],
        role: data.role,
        first_name: data.first_name,
        last_name: data.last_name,
        email: data.email,
        phone: data.phone ?? null,
      };
      return { ...mockStore.users[index] };
    }
    return request<User>("PUT", `/users/${userId}`, data);
  },

  async delete(userId: number): Promise<{ message: string }> {
    if (USE_MOCK) {
      const index = mockStore.users.findIndex((u) => u.id === userId);
      if (index === -1) throw new Error(`User ${userId} not found`);
      mockStore.users.splice(index, 1);
      return { message: "User deleted successfully" };
    }
    return request<{ message: string }>("DELETE", `/users/${userId}`);
  },
};

// ---------------------------------------------------------------------------
// Clients API
// ---------------------------------------------------------------------------

export const clientsApi = {
  async list(): Promise<Client[]> {
    if (USE_MOCK) return [...mockStore.clients];
    return request<Client[]>("GET", "/clients/");
  },

  async get(clientId: number): Promise<Client> {
    if (USE_MOCK) {
      const client = mockStore.clients.find((c) => c.id === clientId);
      if (!client) throw new Error(`Client ${clientId} not found`);
      return { ...client };
    }
    return request<Client>("GET", `/clients/${clientId}`);
  },

  async create(data: ClientCreate): Promise<Client> {
    if (USE_MOCK) {
      const client: Client = {
        id: nextId(),
        first_name: data.first_name,
        last_name: data.last_name,
        email: data.email ?? null,
        phone: data.phone ?? null,
        client_type: data.client_type,
        created_at: now(),
      };
      mockStore.clients.push(client);
      return { ...client };
    }
    return request<Client>("POST", "/clients/", data);
  },

  async update(clientId: number, data: ClientCreate): Promise<Client> {
    if (USE_MOCK) {
      const index = mockStore.clients.findIndex((c) => c.id === clientId);
      if (index === -1) throw new Error(`Client ${clientId} not found`);
      mockStore.clients[index] = {
        ...mockStore.clients[index],
        first_name: data.first_name,
        last_name: data.last_name,
        email: data.email ?? null,
        phone: data.phone ?? null,
        client_type: data.client_type,
      };
      return { ...mockStore.clients[index] };
    }
    return request<Client>("PUT", `/clients/${clientId}`, data);
  },

  async delete(clientId: number): Promise<{ message: string }> {
    if (USE_MOCK) {
      const index = mockStore.clients.findIndex((c) => c.id === clientId);
      if (index === -1) throw new Error(`Client ${clientId} not found`);
      mockStore.clients.splice(index, 1);
      return { message: "Client deleted successfully" };
    }
    return request<{ message: string }>("DELETE", `/clients/${clientId}`);
  },
};

// ---------------------------------------------------------------------------
// Properties API
// ---------------------------------------------------------------------------

export const propertiesApi = {
  async list(): Promise<Property[]> {
    if (USE_MOCK) return [...mockStore.properties];
    return request<Property[]>("GET", "/properties/");
  },

  async get(propertyId: number): Promise<Property> {
    if (USE_MOCK) {
      const property = mockStore.properties.find((p) => p.id === propertyId);
      if (!property) throw new Error(`Property ${propertyId} not found`);
      return { ...property };
    }
    return request<Property>("GET", `/properties/${propertyId}`);
  },

  async create(data: PropertyCreate): Promise<Property> {
    if (USE_MOCK) {
      const property: Property = {
        id: nextId(),
        title: data.title,
        description: data.description ?? null,
        property_type: data.property_type,
        address: data.address,
        city: data.city ?? null,
        price: data.price,
        bedrooms: data.bedrooms ?? null,
        bathrooms: data.bathrooms ?? null,
        area_sqft: data.area_sqft ?? null,
        status: "available",
        created_at: now(),
      };
      mockStore.properties.push(property);
      return { ...property };
    }
    return request<Property>("POST", "/properties/", data);
  },

  async update(propertyId: number, data: PropertyCreate): Promise<Property> {
    if (USE_MOCK) {
      const index = mockStore.properties.findIndex((p) => p.id === propertyId);
      if (index === -1) throw new Error(`Property ${propertyId} not found`);
      mockStore.properties[index] = {
        ...mockStore.properties[index],
        title: data.title,
        description: data.description ?? null,
        property_type: data.property_type,
        address: data.address,
        city: data.city ?? null,
        price: data.price,
        bedrooms: data.bedrooms ?? null,
        bathrooms: data.bathrooms ?? null,
        area_sqft: data.area_sqft ?? null,
      };
      return { ...mockStore.properties[index] };
    }
    return request<Property>("PUT", `/properties/${propertyId}`, data);
  },

  async delete(propertyId: number): Promise<{ message: string }> {
    if (USE_MOCK) {
      const index = mockStore.properties.findIndex((p) => p.id === propertyId);
      if (index === -1) throw new Error(`Property ${propertyId} not found`);
      mockStore.properties.splice(index, 1);
      return { message: "Property deleted successfully" };
    }
    return request<{ message: string }>("DELETE", `/properties/${propertyId}`);
  },
};

// ---------------------------------------------------------------------------
// Property Images API
// ---------------------------------------------------------------------------

export const propertyImagesApi = {
  async list(): Promise<PropertyImage[]> {
    if (USE_MOCK) return [...mockStore.propertyImages];
    return request<PropertyImage[]>("GET", "/property-images/");
  },

  async get(imageId: number): Promise<PropertyImage> {
    if (USE_MOCK) {
      const image = mockStore.propertyImages.find((i) => i.id === imageId);
      if (!image) throw new Error(`Property image ${imageId} not found`);
      return { ...image };
    }
    return request<PropertyImage>("GET", `/property-images/${imageId}`);
  },

  async create(data: PropertyImageCreate): Promise<PropertyImage> {
    if (USE_MOCK) {
      const image: PropertyImage = {
        id: nextId(),
        image_url: data.image_url,
        is_primary: data.is_primary ?? false,
      };
      mockStore.propertyImages.push(image);
      return { ...image };
    }
    return request<PropertyImage>("POST", "/property-images/", data);
  },

  async delete(imageId: number): Promise<{ message: string }> {
    if (USE_MOCK) {
      const index = mockStore.propertyImages.findIndex(
        (i) => i.id === imageId
      );
      if (index === -1)
        throw new Error(`Property image ${imageId} not found`);
      mockStore.propertyImages.splice(index, 1);
      return { message: "Property image deleted successfully" };
    }
    return request<{ message: string }>(
      "DELETE",
      `/property-images/${imageId}`
    );
  },
};

// ---------------------------------------------------------------------------
// Listings API
// ---------------------------------------------------------------------------

export const listingsApi = {
  async list(): Promise<Listing[]> {
    if (USE_MOCK) return [...mockStore.listings];
    return request<Listing[]>("GET", "/listings/");
  },

  async get(listingId: number): Promise<Listing> {
    if (USE_MOCK) {
      const listing = mockStore.listings.find((l) => l.id === listingId);
      if (!listing) throw new Error(`Listing ${listingId} not found`);
      return { ...listing };
    }
    return request<Listing>("GET", `/listings/${listingId}`);
  },

  async create(data: ListingCreate): Promise<Listing> {
    if (USE_MOCK) {
      const listing: Listing = {
        id: nextId(),
        listing_type: data.listing_type,
        listed_price: data.listed_price,
        listing_date: data.listing_date,
        expiry_date: data.expiry_date ?? null,
      };
      mockStore.listings.push(listing);
      return { ...listing };
    }
    return request<Listing>("POST", "/listings/", data);
  },
};

// ---------------------------------------------------------------------------
// Inquiries API
// ---------------------------------------------------------------------------

export const inquiriesApi = {
  async list(): Promise<Inquiry[]> {
    if (USE_MOCK) return [...mockStore.inquiries];
    return request<Inquiry[]>("GET", "/inquiries/");
  },

  async get(inquiryId: number): Promise<Inquiry> {
    if (USE_MOCK) {
      const inquiry = mockStore.inquiries.find((i) => i.id === inquiryId);
      if (!inquiry) throw new Error(`Inquiry ${inquiryId} not found`);
      return { ...inquiry };
    }
    return request<Inquiry>("GET", `/inquiries/${inquiryId}`);
  },

  async create(data: InquiryCreate): Promise<Inquiry> {
    if (USE_MOCK) {
      const inquiry: Inquiry = {
        id: nextId(),
        message: data.message ?? null,
        status: "new",
        created_at: now(),
      };
      mockStore.inquiries.push(inquiry);
      return { ...inquiry };
    }
    return request<Inquiry>("POST", "/inquiries/", data);
  },
};

// ---------------------------------------------------------------------------
// Appointments API
// ---------------------------------------------------------------------------

export const appointmentsApi = {
  async list(): Promise<Appointment[]> {
    if (USE_MOCK) return [...mockStore.appointments];
    return request<Appointment[]>("GET", "/appointments/");
  },

  async get(appointmentId: number): Promise<Appointment> {
    if (USE_MOCK) {
      const appointment = mockStore.appointments.find(
        (a) => a.id === appointmentId
      );
      if (!appointment)
        throw new Error(`Appointment ${appointmentId} not found`);
      return { ...appointment };
    }
    return request<Appointment>("GET", `/appointments/${appointmentId}`);
  },

  async create(data: AppointmentCreate): Promise<Appointment> {
    if (USE_MOCK) {
      const appointment: Appointment = {
        id: nextId(),
        appointment_date: data.appointment_date,
        status: "scheduled",
      };
      mockStore.appointments.push(appointment);
      return { ...appointment };
    }
    return request<Appointment>("POST", "/appointments/", data);
  },
};

// ---------------------------------------------------------------------------
// Transactions API
// ---------------------------------------------------------------------------

export const transactionsApi = {
  async list(): Promise<Transaction[]> {
    if (USE_MOCK) return [...mockStore.transactions];
    return request<Transaction[]>("GET", "/transactions/");
  },

  async get(transactionId: number): Promise<Transaction> {
    if (USE_MOCK) {
      const transaction = mockStore.transactions.find(
        (t) => t.id === transactionId
      );
      if (!transaction)
        throw new Error(`Transaction ${transactionId} not found`);
      return { ...transaction };
    }
    return request<Transaction>("GET", `/transactions/${transactionId}`);
  },

  async create(data: TransactionCreate): Promise<Transaction> {
    if (USE_MOCK) {
      const transaction: Transaction = {
        id: nextId(),
        sale_price: data.sale_price,
        commission: data.commission ?? null,
        transaction_date: data.transaction_date,
      };
      mockStore.transactions.push(transaction);
      return { ...transaction };
    }
    return request<Transaction>("POST", "/transactions/", data);
  },
};

// ---------------------------------------------------------------------------
// Payments API
// ---------------------------------------------------------------------------

export const paymentsApi = {
  async list(): Promise<Payment[]> {
    if (USE_MOCK) return [...mockStore.payments];
    return request<Payment[]>("GET", "/payments/");
  },

  async get(paymentId: number): Promise<Payment> {
    if (USE_MOCK) {
      const payment = mockStore.payments.find((p) => p.id === paymentId);
      if (!payment) throw new Error(`Payment ${paymentId} not found`);
      return { ...payment };
    }
    return request<Payment>("GET", `/payments/${paymentId}`);
  },

  async create(data: PaymentCreate): Promise<Payment> {
    if (USE_MOCK) {
      const payment: Payment = {
        id: nextId(),
        amount: data.amount,
        payment_method: data.payment_method ?? null,
        payment_date: today(),
      };
      mockStore.payments.push(payment);
      return { ...payment };
    }
    return request<Payment>("POST", "/payments/", data);
  },
};

// ---------------------------------------------------------------------------
// Convenience re-export of all APIs as a single object
// ---------------------------------------------------------------------------

export const api = {
  users: usersApi,
  clients: clientsApi,
  properties: propertiesApi,
  propertyImages: propertyImagesApi,
  listings: listingsApi,
  inquiries: inquiriesApi,
  appointments: appointmentsApi,
  transactions: transactionsApi,
  payments: paymentsApi,
};

export default api;
