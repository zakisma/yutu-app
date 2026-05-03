package handlers

import (
	"net/http"
	//  "strconv"
	"github.com/gorilla/websocket"
	// "github.com/zakisma/yutu-app/internal/models"
	// "github.com/zakisma/yutu-app/internal/utils"
	"github.com/zakisma/yutu-app/internal/ws"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true //FFF, add origin restrictions
	},
}

func HandleConnections(hub *ws.Hub, w http.ResponseWriter, r *http.Request) {
	wsConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	hub.AddClient(wsConn)

	go func() {
		defer hub.RemoveClient(wsConn)
		for {
			_, _, err := wsConn.ReadMessage()
			if err != nil {
				break
			}
		}
	}()
}
