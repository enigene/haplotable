$( document ).ready(function() {

    // find row index for column named "sim"
    var simtc;
    $("table tr th").each(function(i){
        if($(this).text() == "simtc"){
            simtc = i;
            return false;
        }
    });
    var simcc;
    $("table tr th").each(function(i){
        if($(this).text() == "simcc"){
            simcc = i;
            return false;
        }
    });

    // https://stackoverflow.com/questions/16213158/use-jquery-to-select-multiple-elements-with-eq
    $.fn.eqAnyOf = function (arrayOfIndexes) {
        return this.filter(function(i) {
            return $.inArray(i, arrayOfIndexes) > -1;
        });
    };

    // first seven character of name in second row used as css class for type consensus name
    var typeConsName  = $('table tr:nth-child(2) td:eq(0)').text().substring(0,7);
    // first seven character of name in third row used as css class for class consensus name
    var classConsName = $('table tr:nth-child(3) td:eq(0)').text().substring(0,7);

    // apply css class for first and second rows
    $('table tr:nth-child(2) td').not($('tr:nth-child(2) td').eqAnyOf([0, simtc, simcc])).addClass(typeConsName);
    $('table tr:nth-child(3) td').not($('tr:nth-child(3) td').eqAnyOf([0, simtc, simcc])).addClass(classConsName);

    $('table tr:gt(2)').each(function() {
         $(this).children('td:gt(0)').not('td:eq(' + (simtc-1) + ')').each(function() {
            var mon = $(this);
            var monText = mon.text();
            var monText = monText.replace(/\s/g, '');
            var columnNum = mon.index();

            var tctArray = [];
            $('table tr:nth-child(2) td:eq(' + columnNum + ')').each(function(){
                tct = $(this).text();
                tct = tct.replace(/\s/g, '');
                tct = tct.replace(/\//g, '');
                tct = tct.split('');
                tctArray.push(tct);
            });
            var cctArray = [];
            $('table tr:nth-child(3) td:eq(' + columnNum + ')').each(function(){
                cct = $(this).text();
                cct = cct.replace(/\s/g, '');
                cct = cct.replace(/\//g, '');
                cct = cct.split('');
                cctArray.push(cct);
            });

            $.each(tctArray, function(i, v){
                if(v.indexOf(monText)>=0){
                    mon.addClass(typeConsName);
                }
            });
            $.each(cctArray, function(i, v){
                if(v.indexOf(monText)>=0){
                    if(mon.hasClass(typeConsName)){
                        mon.removeClass(typeConsName);
                    } else {
                        mon.addClass(classConsName);
                    }
                }
            });
        });
    });
});
