CREATE TABLE IF NOT EXISTS pharma_inventory (
    sku VARCHAR(50) PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL,
    stock_level INTEGER DEFAULT 0,
    logistics_risk_score DECIMAL(3, 2)
);

-- Organizations table for multi-tenant isolation
CREATE TABLE IF NOT EXISTS organizations (
    org_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table with role-based access control
CREATE TABLE IF NOT EXISTS users (
    user_id VARCHAR(50) PRIMARY KEY,
    org_id VARCHAR(50) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin','manager','driver','field_operator')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE
);

-- Stock per organization
CREATE TABLE IF NOT EXISTS org_stock (
    org_id VARCHAR(50) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    stock_level INTEGER DEFAULT 0,
    min_threshold INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (org_id, sku),
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE,
    FOREIGN KEY (sku) REFERENCES pharma_inventory(sku) ON DELETE RESTRICT
);

-- Incidents reported by organizations
CREATE TABLE IF NOT EXISTS incidents (
    incident_id SERIAL PRIMARY KEY,
    org_id VARCHAR(50) NOT NULL,
    incident_type VARCHAR(50) NOT NULL,
    description TEXT,
    location VARCHAR(255),
    severity VARCHAR(20) CHECK (severity IN ('low','medium','high','critical')),
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reported_by VARCHAR(50),
    FOREIGN KEY (org_id) REFERENCES organizations(org_id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by) REFERENCES users(user_id) ON DELETE SET NULL
);
