jQuery(function(i){function a(t){var e=t.attr("value"),a=["_post_simple","_category_simple"];for(key in a)e===a[key]?i("#select"+a[key],n).show().removeAttr("disabled"):i("#select"+a[key],n).hide().attr("disabled","disabled")}function t(t){return 0==t.search("Post,")&&(t="_post_simple"),0==t.search("Category_Post,")&&(t="_category_simple"),t}function l(t){i(".text-slug:not(.runned)",t||n).each(function(){var t=i(this).parents(".panel-item"),a=t.find(".span-title");i(this).slugify(t.find(".text-title"),{slugFunc:function(t,e){return a.html(t),e(t)}}),i(this).addClass("runned")})}var n=i("#cama_custom_field_form"),e=n.attr("data-group_class_name"),s=i("#sortable-fields",n);s.sortable({handle:".panel-sortable"});var r=s.children().length;l(),i("#content-items-default > a",n).click(function(){var t=i(this).attr("href");return showLoading(),i.post(t,function(t){hideLoading();var e=i('<li class="item">'+t+"</li>");s.append(e),l(e);var a=e.find("input.text-title");a.val(a.val()+"-"+r++),a.trigger("keyup"),i('[data-toggle="tooltip"], a[title!=""]',s).tooltip()}),!1}),n.on("click",".panel-delete",function(){var t=i(this).parents(".item:first");return confirm(I18n("msg.delete_item"))&&t.remove(),!1}),i("#select_assign_group",n).change(function(){var t=i(this).find("option:checked");a(t);var e=t.data("help");e&&(e='<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; '+e+" </div>"),i("#select_assign_group_help",n).html(e),i("#select_assign_group_caption",n).val(t.parent("optgroup").attr("label")+" "+t.text())}).val(t(e)).trigger("change"),i("#select_post_simple",n).change(function(){var t=i(this).find("option:checked"),e=t.data("help");e&&(e='<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; '+e+" </div>"),i("#select_assign_group_help",n).html(e),i("#select_assign_group_caption",n).val(t.parent("optgroup").attr("label")+": "+t.text())}).val(e).trigger("change"),i("#select_category_simple",n).change(function(){var t=i(this).find("option:checked"),e=t.data("help");e&&(e='<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; '+e+" </div>"),i("#select_assign_group_help",n).html(e),i("#select_assign_group_caption",n).val(t.parent("optgroup").attr("label")+": "+t.text())}).val(e).trigger("change")});