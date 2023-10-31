# Static S3 Site with Cloudfront module

A terraform module to setup a static site in S3 with files sourced from local disk.

## Usage

~~~
# S3 static site 
module "www" {
  source            = "github.com/joedwards32/tf-modules/static-site"
  dns_zone          = "example.com" 
  site_name         = "www"
  site_files        = "/path/to/site/files"
  subject_alt_names = ["example.com", "www.example.com"]
}
~~~
