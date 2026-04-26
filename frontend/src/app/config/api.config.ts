const runtimeApiBase = (globalThis as { __WROCLAWGO_API_BASE_URL__?: string }).__WROCLAWGO_API_BASE_URL__;

export const API_BASE_URL = runtimeApiBase || 'http://localhost:8000';
export const API_URL = `${API_BASE_URL}/api`;
export const STATIC_BASE_URL = `${API_BASE_URL}/static/`;
