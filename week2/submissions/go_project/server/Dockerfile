FROM golang:alpine

RUN mkdir /app

ADD . /app/

WORKDIR /app

RUN go mod download

COPY . /app/

RUN go build -o main .

EXPOSE 8000

CMD ["./main"]
