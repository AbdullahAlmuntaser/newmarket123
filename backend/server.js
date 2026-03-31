const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const app = express();
const port = 3000;

app.use(cors());
app.use(bodyParser.json());

// Mock Data Store
let products = [
    { 
        id: '1', 
        name: 'Milk', 
        sku: '123456', 
        buyPrice: 1.0, 
        sellPrice: 1.5, 
        stock: 100,
        syncStatus: 0, 
        updatedAt: new Date().toISOString() 
    }
];
let sales = [];

// Auth
app.post('/auth/login', (req, res) => {
    const { username, password } = req.body;
    // Mock login
    if (username === 'admin' && password === 'admin') {
        res.json({ token: 'mock-jwt-token-123', user: { role: 'admin' } });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// Sync Push
app.post('/sync/push', (req, res) => {
    const changes = req.body.changes;
    console.log('Received push:', changes.length, 'changes');
    
    // Process changes...
    if (changes) {
        changes.forEach(change => {
            if (change.entityTable === 'products') {
                // In a real app, you'd update the DB here
                console.log('Updating product:', change.entityId);
            } else if (change.entityTable === 'sales') {
                sales.push(change.payload);
            }
        });
    }
    
    res.json({ success: true, message: 'Synced successfully' });
});

// Sync Pull
app.get('/sync/pull', (req, res) => {
    const since = req.query.since;
    console.log('Client pulling since:', since);
    
    // Filter data updated after 'since'
    // Mocking response
    const newProducts = products; // In real app: filter by date
    
    const changes = newProducts.map(p => ({
        entityTable: 'products',
        operation: 'update',
        payload: p
    }));
    
    res.json({ changes: changes });
});

// Other Endpoints
app.get('/products', (req, res) => res.json(products));
app.get('/sales', (req, res) => res.json(sales));

app.listen(port, () => {
    console.log(`Backend running at http://localhost:${port}`);
});
