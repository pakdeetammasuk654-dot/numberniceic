package service

import (
	"context"
	"fmt"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FirebaseService struct {
	client *messaging.Client
}

func NewFirebaseService(credentialsFile string) (*FirebaseService, error) {
	opt := option.WithCredentialsFile(credentialsFile)
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		return nil, fmt.Errorf("error initializing app: %v", err)
	}

	client, err := app.Messaging(context.Background())
	if err != nil {
		return nil, fmt.Errorf("error getting Messaging client: %v", err)
	}

	return &FirebaseService{client: client}, nil
}

func (s *FirebaseService) SendToToken(token, title, body string, data map[string]string) error {
	message := &messaging.Message{
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data:  data,
		Token: token,
	}

	response, err := s.client.Send(context.Background(), message)
	if err != nil {
		return err
	}
	log.Println("✅ FCM Sent:", response)
	return nil
}

func (s *FirebaseService) SendMulticast(tokens []string, title, body string, data map[string]string) error {
	if len(tokens) == 0 {
		return nil
	}

	message := &messaging.MulticastMessage{
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data:   data,
		Tokens: tokens,
	}

	br, err := s.client.SendEachForMulticast(context.Background(), message)
	if err != nil {
		return err
	}

	if br.FailureCount > 0 {
		log.Printf("⚠️ FCM Multicast: %d successful, %d failed", br.SuccessCount, br.FailureCount)
	} else {
		log.Printf("✅ FCM Multicast: Sent to %d devices", br.SuccessCount)
	}

	return nil
}
