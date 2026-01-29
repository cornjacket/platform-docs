# ADR 0001: Initial Architecture Summary for Cornjacket Platform

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** [Your Name/Gemini]

## 1. Context and Problem Statement
The Cornjacket platform is designed as a high-performance infrastructure for data ingestion, real-time AI inference, and event orchestration (initially targeting IoT or security streams). The goal is to practice advanced software engineering patterns including scalability, resilience, and "Security by Design."

The system must handle high-velocity "Write" traffic while remaining responsive to complex "Query" requests and AI-driven analysis.

## 2. Design Choices & Decisions

### 2.1 Entry Point Strategy: Parallel Entry (Best Approach)
* **Decision:** Separate the entry points for different protocols. Use an **Off-the-shelf API Gateway** (e.g., Kong, Traefik) for HTTP traffic and an **Off-the-shelf MQTT Broker** (e.g., EMQX) for stateful TCP IoT traffic.
* **Reasoning:** Protocol isolation prevents long-lived MQTT connections from consuming resources needed by short-lived HTTP requests. Using off-the-shelf tools ensures battle-tested security and protocol compliance.

### 2.2 Data Flow Pattern: Event-Driven Message Bus (Best Approach)
* **Decision:** Utilize a centralized **Message Bus** (e.g., Kafka or Redpanda) as the "unifier."
* **Reasoning:** Decouples ingestion from processing. It acts as a buffer (pressure valve) to protect downstream databases (TSDB) and AI services from traffic spikes (backpressure management).

### 2.3 Structural Philosophy: CQRS (Best Approach)
* **Decision:** Implement **Command Query Responsibility Segregation**. 
    * The **Ingestion Service** handles writes.
    * The **Query API** handles reads and data retrieval.
* **Reasoning:** Scaling requirements for writes (high-volume, low-latency) are fundamentally different from reads (complex aggregations, AI-enriched data). This prevents heavy queries from slowing down data ingestion.

### 2.4 AI Integration: In-Flight Inference (Best Approach)
* **Decision:** Deploy the AI Inference engine as a **Stream Processor/Consumer** on the message bus.
* **Reasoning:** Allows for real-time anomaly detection and predictive actions. Data is enriched *before* it hits the permanent storage (TSDB), enabling immediate responses via the Action Orchestrator.

### 2.5 Build vs. Buy: Hybrid Integration (Best Approach)
* **Decision:** Use off-the-shelf software for infrastructure (Gateway, Broker, Bus, TSDB). Develop **Custom Go Services** for business logic, ingestion validation, and action orchestration. Develop **Custom Python Services** for AI modeling.
* **Reasoning:** Focuses engineering effort on the unique architectural logic and AI implementation rather than reinventing standard networking protocols.

## 3. Subsystem Overview

| Subsystem | Tech Category | Responsibility |
| :--- | :--- | :--- |
| **API Gateway** | Off-the-shelf | HTTP Auth, Rate-limiting, Routing. |
| **MQTT Broker** | Off-the-shelf | Managing IoT device connections and Pub/Sub. |
| **Message Bus** | Infrastructure | Central data pipeline (Kafka/Redpanda). |
| **Ingestion Service** | Custom (Go) | Validating and cleaning data; pushing to Bus. |
| **AI Inference** | Custom (Python) | In-flight anomaly detection and forecasting. |
| **TSDB** | Database | Long-term historical storage (InfluxDB/Timescale). |
| **Query API** | Custom (Go) | Serving data and AI insights via HTTP. |
| **Action Orchestrator**| Custom (Go) | Triggering webhooks/alerts based on AI logic. |

## 4. Consequences
* **Pros:** Highly scalable, protocol-agnostic, and supports real-time AI capabilities.
* **Cons:** Higher initial setup complexity; requires managing a distributed message bus and multiple service deployments.