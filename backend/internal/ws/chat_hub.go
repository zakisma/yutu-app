package ws

import (
	"sync"

	"github.com/gorilla/websocket"
)

// manages active private connections
type ChatHub struct {
	sync.RWMutex
	Clients map[int]*websocket.Conn // maps a userid directly to their active (phone) connection
}

func NewChatHub() *ChatHub {
	return &ChatHub{
		Clients: make(map[int]*websocket.Conn),
	}
}

// Register saves the user's connection when they open the app
func (h *ChatHub) Register(userID int, conn *websocket.Conn) {
	h.Lock()
	defer h.Unlock()
	h.Clients[userID] = conn
}

// Unregister removes the connection when they close the app or log out
func (h *ChatHub) Unregister(userID int) {
	h.Lock()
	defer h.Unlock()
	delete(h.Clients, userID)
}

// acts as the sniper: It finds the exact user and fires the message to them
func (h *ChatHub) SendToUser(userID int, message interface{}) {
	h.RLock()
	defer h.RUnlock()
	if conn, ok := h.Clients[userID]; ok {
		// If the user is currently online, push the JSON to their phone
		conn.WriteJSON(message)
	}
}
