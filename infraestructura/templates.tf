#esto inyecta el url directamente en el html cuando se crea

resource "local_file" "html_renderizado" {
  content  = templatefile("${path.module}/../sitio-web/index.html.tpl", {
    api_url = aws_apigatewayv2_api.http_api.api_endpoint
  })
  
  filename = "${path.module}/../sitio-web/index.html"
}