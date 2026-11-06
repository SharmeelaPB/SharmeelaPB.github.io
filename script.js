document.querySelectorAll('details').forEach(detail=>detail.addEventListener('toggle',()=>{detail.querySelector('summary').setAttribute('aria-expanded',String(detail.open));}));
