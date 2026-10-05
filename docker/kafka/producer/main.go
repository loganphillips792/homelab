// Kafka producer for the homelab testing stack.
//
// One endpoint, POST /produce, publishes a random JSON object to the topic that
// kafka-consumer reads, so a single curl drives the whole pipeline end to end.
//
// Configured entirely by environment variable; the values live in
// ../docker-compose.yml, using the same names as the consumer.
package main

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	mrand "math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/twmb/franz-go/pkg/kadm"
	"github.com/twmb/franz-go/pkg/kerr"
	"github.com/twmb/franz-go/pkg/kgo"
)

var commands = []string{"scan", "rescan", "purge", "index", "verify"}

// Command is the random object published on every request.
type Command struct {
	ID        string    `json:"id"`
	Command   string    `json:"command"`
	Target    string    `json:"target"`
	Priority  int       `json:"priority"`
	CreatedAt time.Time `json:"created_at"`
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func randomCommand() Command {
	return Command{
		ID:        rand.Text(),
		Command:   commands[mrand.IntN(len(commands))],
		Target:    fmt.Sprintf("host-%02d", mrand.IntN(100)),
		Priority:  mrand.IntN(5) + 1,
		CreatedAt: time.Now().UTC(),
	}
}

// ensureTopic creates the topic if it is missing, with the right partition count.
//
// Same reasoning as ensure_topic() in the consumer: the broker runs with
// KAFKA_AUTO_CREATE_TOPICS_ENABLE=true, so if this service wins the startup race
// its first produce would auto-create the topic with a single partition.
func ensureTopic(ctx context.Context, cl *kgo.Client, topic string, partitions int32) error {
	_, err := kadm.NewClient(cl).CreateTopic(ctx, partitions, 1, nil, topic)
	if err == nil {
		log.Printf("created topic %q with %d partitions", topic, partitions)
		return nil
	}
	if errors.Is(err, kerr.TopicAlreadyExists) {
		return nil
	}
	return err
}

func main() {
	bootstrap := env("KAFKA_BOOTSTRAP", "kafka:29092")
	topic := env("KAFKA_TOPIC", "scan.commands")
	port := env("PORT", "8080")
	partitions, err := strconv.Atoi(env("KAFKA_TOPIC_PARTITIONS", "3"))
	if err != nil {
		log.Fatalf("KAFKA_TOPIC_PARTITIONS: %v", err)
	}

	cl, err := kgo.NewClient(kgo.SeedBrokers(bootstrap), kgo.DefaultProduceTopic(topic))
	if err != nil {
		log.Fatalf("kafka client: %v", err)
	}
	defer cl.Close() // flushes anything still buffered

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	err = ensureTopic(ctx, cl, topic, int32(partitions))
	cancel()
	if err != nil {
		log.Fatalf("ensure topic %q: %v", topic, err)
	}

	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.RequestLogger(), middleware.Recover())

	e.POST("/produce", func(c echo.Context) error {
		cmd := randomCommand()
		value, err := json.Marshal(cmd)
		if err != nil {
			return err
		}
		// Keyed by id, so messages spread across partitions; the consumer's
		// p<partition>@<offset> log line shows where each one landed.
		rec := &kgo.Record{Key: []byte(cmd.ID), Value: value}
		if err := cl.ProduceSync(c.Request().Context(), rec).FirstErr(); err != nil {
			return echo.NewHTTPError(http.StatusBadGateway, err.Error())
		}
		return c.JSON(http.StatusCreated, map[string]any{
			"topic":     rec.Topic,
			"partition": rec.Partition,
			"offset":    rec.Offset,
			"message":   cmd,
		})
	})

	go func() {
		log.Printf("producing to %q via %s, listening on :%s", topic, bootstrap, port)
		if err := e.Start(":" + port); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http server: %v", err)
		}
	}()

	// Docker sends SIGTERM on `compose down`/`stop`.
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	log.Printf("received %s, shutting down", <-sig)

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := e.Shutdown(shutdownCtx); err != nil {
		log.Printf("http shutdown: %v", err)
	}
}
