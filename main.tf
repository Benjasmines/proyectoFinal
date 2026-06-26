resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = { Name = "${var.project}-vpc" }
}
resource "aws_subnet" "a" {
    vpc_id   = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"
}
resource "aws_s3_bucket" "datos" {
    bucket = "${var.project}-datos-55"
}