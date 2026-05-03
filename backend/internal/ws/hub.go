package ws

import (
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// has a list of active cients and sends them messages
type Hub struct {
	clients   map[*websocket.Conn]bool
	Broadcast chan []byte
	mutex     sync.Mutex
}

func NewHub() *Hub {
	return &Hub{
		clients:   make(map[*websocket.Conn]bool),
		Broadcast: make(chan []byte),
	}
}

// adds a new user
func (h *Hub) AddClient(conn *websocket.Conn) {
	h.mutex.Lock()
	defer h.mutex.Unlock()
	h.clients[conn] = true
	log.Println("New WebSocket client connected. Total:", len(h.clients))
}

func (h *Hub) RemoveClient(conn *websocket.Conn) {
	h.mutex.Lock()
	defer h.mutex.Unlock()
	if _, ok := h.clients[conn]; ok {
		delete(h.clients, conn)
		conn.Close()
		log.Println("WebSocket client disconnected. Total:", len(h.clients))
	}
}

// listens on the broadcast channel and sends messages
func (h *Hub) Run() {
	for {
		message := <-h.Broadcast // waits for incoming messages
		h.mutex.Lock()
		for client := range h.clients {
			err := client.WriteMessage(websocket.TextMessage, message)
			if err != nil {
				client.Close()
				delete(h.clients, client)
			}
		}
		h.mutex.Unlock()
	}
}
