document.addEventListener('DOMContentLoaded', function () {
  const btnAdd = document.getElementById('btn-add');
  const modalEl = document.getElementById('productModal');
  const productForm = document.getElementById('product-form');
  const modal = new bootstrap.Modal(modalEl);

  function openModalForAdd() {
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-plus-circle"></i><span>Add Product</span>';
    productForm.reset();
    document.getElementById('product-id').value = '';
    document.getElementById('img-preview').src = '/images/placeholder-80.png';
    document.getElementById('imageUrl').value = '';
    modal.show();
  }

  function openModalForEdit(row) {
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i><span>Edit Product</span>';
    const id = row.dataset.id;
    document.getElementById('product-id').value = id;
    
    // Get data from dataset attributes for accurate values
    document.getElementById('name').value = row.dataset.name || '';
    document.getElementById('price').value = row.dataset.price || '';
    document.getElementById('color').value = row.dataset.color || '';
    document.getElementById('description').value = row.dataset.description || '';
    
    const existingImage = row.dataset.image || '';
    document.getElementById('img-preview').src = existingImage && existingImage.length ? existingImage : '/images/placeholder-80.png';
    document.getElementById('imageUrl').value = existingImage || '';
    modal.show();
  }

  btnAdd.addEventListener('click', openModalForAdd);

  document.getElementById('product-table').addEventListener('click', function (e) {
    const tr = e.target.closest('tr');
    if (!tr) return;
    if (e.target.classList.contains('btn-edit') || e.target.closest('.btn-edit')) {
      openModalForEdit(tr);
    } else if (e.target.classList.contains('btn-delete') || e.target.closest('.btn-delete')) {
      const id = tr.dataset.id;
      const productName = tr.dataset.name || 'this product';
      showDeleteModal(productName, id);
    }
  });

  // Show Delete Modal
  function showDeleteModal(productName, productId) {
    document.getElementById('delete-product-name').textContent = productName;
    const deleteModal = new bootstrap.Modal(document.getElementById('deleteModal'));
    deleteModal.show();
    
    // Set up delete confirmation
    document.getElementById('btn-confirm-delete').onclick = function() {
      performDelete(productId);
      deleteModal.hide();
    };
  }

  function performDelete(id) {
    fetch(`/products/${id}`, { method: 'DELETE' }).then(r => {
      if (r.ok) {
        location.reload();
      } else {
        r.json().then(j => alert('❌ Error: ' + (j.message || 'Delete failed')));
      }
    }).catch(() => alert('❌ Error: Delete failed'));
  }

  productForm.addEventListener('submit', function (e) {
    e.preventDefault();
    const id = document.getElementById('product-id').value;
    // Basic client-side validation
    const name = document.getElementById('name').value.trim();
    const price = Number(document.getElementById('price').value);
    const color = document.getElementById('color').value.trim();
    if (!name || !color || !price) {
      alert('Please provide name, price and color');
      return;
    }

    const formData = new FormData();
    formData.append('name', name);
    formData.append('price', price);
    formData.append('color', color);
    formData.append('description', document.getElementById('description').value.trim());
    const file = document.getElementById('imageFile').files[0];
    if (file) formData.append('imageFile', file);

    const method = id ? 'PATCH' : 'POST';
    const url = id ? `/products/${id}` : '/products';

    fetch(url, { method, body: formData })
      .then(r => {
        if (r.ok) location.reload();
        else r.json().then(j => alert((j && j.errors) ? j.errors.map(e => e.msg).join('\n') : (j.message || 'Save failed')));
      })
      .catch(() => alert('Save failed'));
  });

  // handle file input preview and set hidden imageUrl as data URL
  const imageFileInput = document.getElementById('imageFile');
  imageFileInput.addEventListener('change', function (e) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function (ev) {
      const dataUrl = ev.target.result;
      document.getElementById('img-preview').src = dataUrl;
      document.getElementById('imageUrl').value = dataUrl;
    };
    reader.readAsDataURL(file);
  });
});
