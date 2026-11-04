# ExamEval

AI evaluation of **handwritten university exam answer books in Hindi (Devanagari) and English**, built for
Indian state universities. Built for the Meta Global AI Developer Hackathon (Indie Developer track).

Teachers set up an exam with a rubric and upload scanned PDFs or phone photos. ExamEval runs an agent pipeline
built on Meta models:

1. **Prepare pages** — PDFs and photos are rasterised and normalised (`pdftoppm`, ImageMagick).
2. **Find answers** — **SAM 3.1** segments the handwritten answer blocks on each page.
3. **Read** — **Muse Spark** (vision) transcribes the handwriting and maps each block to a question number.
4. **Grade** — **Muse Spark** marks each answer criterion by criterion against the rubric, quoting evidence.
5. **Moderate** — an independent **Muse Spark** moderator re-checks the page images and the marks, then agrees,
   adjusts or flags each answer.
6. **Human review** — uncertain answers go to a teacher review screen with page images, SAM boxes, the agent
   trace, and one-click override or confirm.

The exam page also shows how often the AI agreed with the teacher (agreement rate, mean absolute error).

## Run locally

Requirements: Ruby 3.2+, SQLite, `poppler-utils` (`pdftoppm`) and ImageMagick.

```sh
bundle install
cp .env.example .env          # then set MODEL_API_KEY (Meta Model API key)
bin/rails db:setup            # creates the database and a demo exam
bin/rails server
```

Check your API key without Rails: `ruby script/meta_smoke_test.rb [page.jpg]`.

## Stack

Rails 8, SQLite, Active Storage, Active Job, Hotwire, plain CSS. Meta Model API (Responses API, structured output).

No real student data is used. Demo answer books are written for the demo.
