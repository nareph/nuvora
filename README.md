# Nuvora

> **Local-First AI Health Intelligence System**

Nuvora is a next-generation personal health platform designed around deterministic decision engines, local-first data storage, and explainable artificial intelligence.

Unlike traditional fitness applications that generate static workout plans, Nuvora continuously adapts to the user's progress, recovery, nutrition, and health data to provide personalized daily recommendations.

---

# Vision

Nuvora aims to become a **Personal AI Health Operating System**.

Instead of asking:

> "Generate me a workout."

Nuvora answers:

> **"Given everything we know about you today, what is the best action to improve your health?"**

---

# Core Principles

* Local-First Architecture
* Offline by Default
* Explainable AI
* Deterministic Decision Making
* Evidence-Based Fitness
* Modular Domain Architecture
* Long-Term Personalization

---

# Architecture Overview

```text
Presentation Layer (Flutter UI)
            │
            ▼
State Management (ViewModels)
            │
            ▼
Repository Layer
            │
            ▼
Service Layer
            │
            ▼
Domain Engines
    ├── Workout Engine
    ├── Nutrition Engine
    ├── Recovery Engine
    └── Progress Engine
            │
            ▼
Decision Engine
            │
            ▼
AI Coach
            │
            ▼
Hive Local Database
```

The Decision Engine orchestrates all domain engines and produces a single coherent recommendation for the user.

---

# Documentation Structure

```text
docs/
│
├── 00-introduction/
├── 01-research/
├── 02-product/
├── 03-system-design/
├── 04-ai-architecture/
├── 05-development/
├── 06-testing/
└── assets/
```

The documentation is organized from product vision and research to system design, implementation, and testing.

---

# Core Intelligence Modules

Nuvora is composed of specialized deterministic engines.

* Workout Engine
* Nutrition Engine
* Recovery Engine
* Progress Engine
* Decision Engine
* AI Coach

Each module has a single responsibility and communicates through structured internal contracts.

---

# Training Model

Nuvora distinguishes between three different concepts.

## Training Program

A complete multi-week training strategy.

Example:

* 6 weeks
* Upper / Lower Split
* Progressive Overload Strategy

---

## Weekly Training Plan

The weekly schedule generated from the training program.

Example:

```text
Monday    → Upper A
Tuesday   → Lower A
Thursday  → Upper B
Friday    → Lower B
```

---

## Training Session

The workout scheduled for a specific day.

The Decision Engine may adapt today's session according to:

* recovery
* fatigue
* soreness
* progress
* adherence

without modifying the entire Training Program.

---

# Exercise Bank

Nuvora ships a **curated, slimmed exercise catalog** derived from the open-source:

https://github.com/hasaneyldrm/exercises-dataset

The upstream dataset contains approximately **1,324 exercises**, with exercise demonstrations, thumbnails, multiple languages, body-part information, equipment, target muscles, and step-by-step instructions.

The upstream dataset is not used directly by the Workout Engine.

Instead, Nuvora generates a local catalog that is:

* filtered
* normalized
* translated
* enriched with Nuvora-specific taxonomy
* validated before being included in the application

This keeps the external dataset isolated from the domain layer while allowing the Workout Engine to use a stable Nuvora-specific exercise contract.

---

## Exercise Data Pipeline

```text
Upstream Exercise Dataset
            │
            ▼
    Raw exercise records
            │
            ▼
  Exercise catalog generator
            │
            ▼
   Nuvora taxonomy
            │
            ▼
      Validation / QC
            │
            ▼
     Local exercise bank
            │
            ▼
      Workout Engine
```

The Workout Engine must not depend directly on the upstream dataset schema.

---

## What ships in the app

| File / Directory                          | Purpose                                                     |
| ----------------------------------------- | ----------------------------------------------------------- |
| `assets/exercises/exercises.json`         | Slim exercise catalog containing the required exercise data |
| `assets/exercises/exercise_taxonomy.json` | Nuvora-specific exercise classification                     |
| `assets/exercises/videos/*.gif`           | Exercise demonstration animations                           |
| `assets/exercises/images/*.jpg`           | Exercise thumbnails                                         |

Binary exercise media is stored using **Git LFS**.

The JSON catalogs remain normally versioned so they can be reviewed and diffed through Git.

---

## Exercise Taxonomy

The external dataset provides information such as:

* exercise name
* body part
* equipment
* target muscle
* muscle group
* secondary muscles
* instructions
* instruction steps
* media identifiers

Nuvora's taxonomy adds the classification required by the Workout Engine and exercise selector.

The taxonomy can contain concepts such as:

* movement family
* primary muscle
* secondary muscles
* equipment type
* body region
* exercise type
* difficulty
* movement pattern
* bodyweight classification
* timed/repetition classification
* selector eligibility

The taxonomy is intentionally separated from the external dataset so that Workout Engine rules remain owned by Nuvora.

---

## Workout Prescription

The exercise bank describes **what an exercise is**.

The Workout Engine decides **how the exercise is prescribed**.

The exercise dataset does not define Nuvora's:

* sets
* repetitions
* rest periods
* training volume
* progression
* load
* session structure
* training objective

Those decisions remain deterministic Workout Engine responsibilities.

For example:

```text
Exercise Bank
    │
    │  "Barbell Bench Press"
    ▼
Exercise
    │
    ▼
Workout Engine
    │
    ├── sets
    ├── reps
    ├── rest
    ├── load
    └── progression
```

This separation allows the exercise bank to evolve without coupling exercise data to workout programming logic.

---

# Exercise Media

Each exercise may provide:

* thumbnail image
* animated GIF demonstration
* media identifier
* attribution information

The application can use these assets to visually illustrate exercises during:

* exercise selection
* workout preparation
* workout execution
* exercise details
* exercise substitution

Media is presentation data and must not become a dependency of the deterministic exercise-selection logic.

---

# Data Source and Attribution

The exercise catalog is derived from:

https://github.com/hasaneyldrm/exercises-dataset

The upstream dataset contains exercise media and attribution information.

Nuvora preserves the relevant attribution information and follows the licensing and NOTICE requirements associated with the source dataset and its media.

The raw upstream dataset is not required to be shipped with the application.

---

# Regenerating the Exercise Catalog

The local exercise catalog can be regenerated from the upstream dataset.

## 1. Download the raw dataset

From the root of the project:

```bash
mkdir -p data_source

curl -L -o data_source/exercises.json \
  https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json
```

---

## 2. Generate the Nuvora exercise catalog

```bash
python3 scripts/generate_exercise_taxonomy.py
```

This generates:

```text
assets/exercises/exercises.json
assets/exercises/exercise_taxonomy.json
assets/exercises/taxonomy_report.json
```

The generated catalog contains only the information required by Nuvora.

---

## 3. Validate the taxonomy

```bash
python3 scripts/verify_taxonomy.py
```

The validation step checks the generated taxonomy and reports structural or classification problems before the catalog is used by the application.

---

# Exercise Catalog Reproducibility

The raw upstream dataset is intentionally kept outside the versioned application catalog.

```text
data_source/
    └── exercises.json
```

This directory is used as a reproducible generation source.

The generated application files are:

```text
assets/
└── exercises/
    ├── exercises.json
    ├── exercise_taxonomy.json
    ├── videos/
    └── images/
```

The generated taxonomy report is not versioned.

---

# What is Not Versioned

| Path                                    | Reason                                                        |
| --------------------------------------- | ------------------------------------------------------------- |
| `data_source/`                          | Raw upstream dataset; reproducible from the source repository |
| `assets/exercises/taxonomy_report.json` | Automatically generated quality-control report                |

These paths should be included in `.gitignore`.

---

# Media Handling — Git LFS

Binary exercise media is stored using Git LFS.

The repository should contain the following `.gitattributes` configuration:

```gitattributes
*.gif filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
```

Contributors should install Git LFS once per machine:

```bash
git lfs install
```

Then clone the repository:

```bash
git clone https://github.com/nareph/nuvora.git
cd nuvora
```

If necessary, download the LFS objects:

```bash
git lfs pull
```

If media files appear as plain text containing:

```text
version https://git-lfs.github.com/spec/v1
```

run:

```bash
git lfs pull
```

JSON catalogs are intentionally **not** tracked by Git LFS because they should remain directly diffable and reviewable.

---

# Scripts

| Script                                  | Role                                                    |
| --------------------------------------- | ------------------------------------------------------- |
| `scripts/generate_exercise_taxonomy.py` | Generates the slim exercise catalog and Nuvora taxonomy |
| `scripts/verify_taxonomy.py`            | Validates the generated taxonomy and performs QC checks |

---

# Local-First Philosophy

Nuvora stores user data locally using Hive.

The application is designed to function without an internet connection.

Core health intelligence therefore remains available locally and does not depend on a permanent cloud connection.

Cloud synchronization is considered an optional future capability rather than a requirement for the core application.

---

# AI Philosophy

Artificial Intelligence does **not** make business or health decisions inside the deterministic domain engines.

The deterministic engines compute structured results such as:

* workout programming
* nutrition targets
* recovery analysis
* progress evaluation
* daily recommendations

The AI Coach is responsible only for:

* explanations
* coaching
* motivation
* natural language generation

The AI Coach should explain the decisions produced by the deterministic system rather than replacing those decisions.

---

# Decision Engine

The Decision Engine is responsible for orchestrating the different health intelligence modules.

```text
User Data
    │
    ├── Workout Data
    ├── Nutrition Data
    ├── Recovery Data
    └── Progress Data
            │
            ▼
     Domain Engines
            │
            ▼
      Decision Engine
            │
            ▼
       Daily Plan
            │
            ▼
         AI Coach
```

The Decision Engine produces a coherent recommendation instead of exposing isolated recommendations from each individual engine.

---

# Daily Health Intelligence

Nuvora is designed around a simple daily question:

> **"What is the best action I can take today to improve my health?"**

The answer should consider the user's available data and the deterministic outputs of the domain engines.

Possible factors include:

* training status
* recovery
* nutrition
* recent progress
* adherence
* health measurements
* current goals

The system should favor actionable recommendations rather than overwhelming the user with disconnected metrics.

---

# Current Status

The v3 architecture contains the foundation for Nuvora's health intelligence platform, including:

* Product Architecture
* System Design
* Database Design
* Internal API Contracts
* Workout Engine
* Nutrition Engine
* Recovery Engine
* Progress Engine
* Decision Engine
* AI Coach Architecture
* Exercise Bank
* Nuvora Exercise Taxonomy
* Exercise Media Pipeline
* Development Guidelines
* Testing Strategy

The project is evolving from the original GymGenius architecture into the **Nuvora** product identity.

The internal package and technical identifiers may temporarily retain historical names where necessary during the migration.

---

# Roadmap

Nuvora evolves progressively through five stages.

## 1. Foundation

Establish the local-first architecture and deterministic health engines.

## 2. Intelligent Coaching

Introduce explainable AI coaching on top of deterministic engine outputs.

## 3. Advanced Intelligence

Expand personalization, health intelligence, and cross-domain decision making.

## 4. Connected Health Ecosystem

Integrate optional external health and wearable data sources.

## 5. Personal AI Health Operating System

Evolve Nuvora into a comprehensive personal health intelligence platform.

---

# Technology Stack

* Flutter
* Dart
* Hive
* Local-First Storage
* Modular Clean Architecture
* Deterministic Domain Engines
* Git LFS for binary exercise media

---

# Project Philosophy

Nuvora follows one fundamental rule:

> **Every recommendation must be explainable, deterministic, and driven by real user data.**

The application should adapt to the user.

The user should never have to adapt to the application.

---

# Development Philosophy

Nuvora prioritizes:

* correctness over complexity
* deterministic behavior over opaque decisions
* local-first functionality over cloud dependency
* modular architecture over tightly coupled features
* explainability over black-box recommendations
* incremental development over premature abstraction

Every new feature should respect the existing domain boundaries and avoid moving business logic into the presentation layer.

---

# Data Integrity

Health recommendations must be based on actual available data.

Nuvora should never invent:

* user measurements
* workout history
* nutrition data
* recovery information
* progress
* exercise characteristics
* health results

When required information is unavailable, the system should explicitly represent that uncertainty rather than silently assuming a value.

---

# Testing Philosophy

Each deterministic engine should be independently testable.

Tests should cover:

* domain rules
* edge cases
* data transformations
* exercise selection
* nutrition calculations
* recovery calculations
* progress calculations
* Decision Engine outputs

The AI Coach should be tested separately from the deterministic decision logic.

The objective is to ensure that changes to AI presentation cannot silently change the underlying health decisions.

---

# Repository Principles

The repository should keep generated artifacts and source data clearly separated.

```text
Source
  │
  ├── application code
  ├── domain models
  ├── deterministic engines
  ├── scripts
  └── documentation
        │
        ▼
Generated Assets
  │
  ├── exercise catalog
  ├── taxonomy
  └── media
```

Generated files should be reproducible whenever practical.

External datasets should not become hidden runtime dependencies.

---

# Final Principle

Nuvora is not simply a workout generator.

It is being built as a **local-first personal health intelligence system**.

Its purpose is to combine real user data, deterministic health reasoning, explainable recommendations, and optional AI coaching into one coherent daily experience.

> **Nuvora helps the user make better health decisions — every day.**
