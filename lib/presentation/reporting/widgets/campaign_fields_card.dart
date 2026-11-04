import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/campaign_models.dart';


class CampaignFieldsCard extends StatelessWidget {
  final CampaignFieldDefinition campaign;
  final Map<String, dynamic> values;
  final bool readOnly;
  final Function(String fieldName, dynamic value) onFieldChanged;

  const CampaignFieldsCard({
    super.key,
    required this.campaign,
    required this.values,
    this.readOnly = false,
    required this.onFieldChanged,
  });

  static const Color primaryPurple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    final sortedFields = List<DynamicField>.from(campaign.dynamicFields)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade50.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryPurple.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.purple.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: primaryPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: primaryPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.campaignName.isNotEmpty
                            ? campaign.campaignName
                            : "Campaign Details",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryPurple,
                        ),
                      ),
                      if (campaign.description != null &&
                          campaign.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          campaign.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    "Active",
                    style: GoogleFonts.poppins(
                      color: Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: sortedFields.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "No additional dynamic fields required for this campaign.",
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < sortedFields.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        _DynamicFieldInputField(
                          key: ValueKey(
                              "${campaign.campaignId}_${sortedFields[i].fieldName}"),
                          field: sortedFields[i],
                          initialValue: values[sortedFields[i].fieldName],
                          readOnly: readOnly,
                          onFieldChanged: onFieldChanged,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DynamicFieldInputField extends StatefulWidget {
  final DynamicField field;
  final dynamic initialValue;
  final bool readOnly;
  final Function(String fieldName, dynamic value) onFieldChanged;

  const _DynamicFieldInputField({
    super.key,
    required this.field,
    required this.initialValue,
    required this.readOnly,
    required this.onFieldChanged,
  });

  @override
  State<_DynamicFieldInputField> createState() => _DynamicFieldInputFieldState();
}

class _DynamicFieldInputFieldState extends State<_DynamicFieldInputField> {
  late TextEditingController _controller;
  static const Color primaryPurple = Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null ? widget.initialValue.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant _DynamicFieldInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText =
        widget.initialValue != null ? widget.initialValue.toString() : '';
    if (newText != _controller.text && widget.initialValue != null) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final isDecimal = field.uiComponent == 'decimal_input' ||
        field.fieldType == 'decimal' ||
        field.keyboardType.toLowerCase().contains('decimal');
    final isNumber = !isDecimal &&
        (field.uiComponent == 'numeric_input' ||
            field.fieldType == 'number' ||
            field.keyboardType.toLowerCase().contains('number'));

    List<TextInputFormatter> formatters = [];
    TextInputType keyboardType = TextInputType.text;

    if (isDecimal) {
      keyboardType = const TextInputType.numberWithOptions(decimal: true);
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ];
    } else if (isNumber) {
      keyboardType = TextInputType.number;
      formatters = [
        FilteringTextInputFormatter.digitsOnly,
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                field.fieldLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (field.isRequired) ...[
              const SizedBox(width: 3),
              Text(
                '*',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: widget.readOnly ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _controller,
            readOnly: widget.readOnly,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: "Enter ${field.fieldLabel.toLowerCase()}",
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                isDecimal || isNumber
                    ? Icons.numbers_outlined
                    : Icons.edit_note_outlined,
                color: primaryPurple,
                size: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryPurple, width: 1.5),
              ),
            ),
            onChanged: (val) {
              final trimmed = val.trim();
              if (trimmed.isEmpty) {
                widget.onFieldChanged(field.fieldName, null);
                return;
              }

              if (isDecimal) {
                final parsed = double.tryParse(trimmed);
                widget.onFieldChanged(field.fieldName, parsed ?? trimmed);
              } else if (isNumber) {
                final parsed = int.tryParse(trimmed);
                widget.onFieldChanged(field.fieldName, parsed ?? trimmed);
              } else {
                widget.onFieldChanged(field.fieldName, trimmed);
              }
            },
          ),
        ),
      ],
    );
  }
}
