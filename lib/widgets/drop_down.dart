import 'package:flutter/material.dart';

class CustomDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T?>? onChanged;
  final double height;
  final double width;
  final String? Function(T?)? validator;
  final bool isDisabled;
  final String Function(T?) getItemLabel;
  final String label;

  const CustomDropdown({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.getItemLabel,
    this.height = 50.0,
    this.width = 200.0,
    this.validator,
    required this.isDisabled,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: validator,
      builder: (FormFieldState<T> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height,
              width: width,
              padding: const EdgeInsets.only(left: 18, right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: state.hasError
                      ? Colors.red
                      : isDisabled
                          ? Colors.grey.shade400
                          : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: selectedItem,
                  onChanged: isDisabled
                      ? null
                      : (value) {
                          if (value != null) {
                            onChanged?.call(value);
                            state.didChange(value);
                          }
                        },
                  isExpanded: true,
                  items: items.map((item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text(getItemLabel(item)),
                    );
                  }).toList(),
                  icon: const Icon(Icons.arrow_drop_down),
                  hint: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 1.2),
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 10),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}


